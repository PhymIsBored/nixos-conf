{
  config,
  lib,
  pkgs,
  ...
}:
let
  folderId = "hermes-brain";
  brainDir = ".hermes-brain";

  deviceIds = {
    lapnix = {
      id = "RQ7B7OA-6WTCGAK-K5EN7HD-FDOHPB6-3KAEYNH-DKBZB2J-MX7IHDT-MEOCWQ7";
    };
    desknix = {
      id = "UUFGIHM-GHE6EKF-UEVIXNE-Y5YRVHI-4FNK2SL-4BGIP5G-SCQSZST-TBLMIAK";
    };
    finn_server = {
      id = "QLJVWA2-U5ZYLIH-WEQ3AYO-25RADUN-Y2VLOVE-OPX3GXT-BHTD6VC-E5LKAQY";
      introducer = true;
    };
  };

  self = config.networking.hostName;
  peers = removeAttrs deviceIds [ self ];

  mergeConflicts = pkgs.writeTextFile {
    name = "hermes-brain-merge-conflicts";
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      import json
      import os
      import re
      import subprocess
      import sys
      import tempfile
      from pathlib import Path

      mem_dir = Path(sys.argv[1])
      cfg_path = Path(sys.argv[2])
      conflicts = sorted(mem_dir.glob("*.sync-conflict-*.md"))
      if not conflicts:
          sys.exit(0)

      def read_limits() -> dict[str, int]:
          limits = {"MEMORY": 2200, "USER": 1375}
          if not cfg_path.is_file():
              return limits
          text = cfg_path.read_text(encoding="utf-8", errors="replace")
          in_mem = False
          for line in text.splitlines():
              if re.match(r"^memory:\s*$", line):
                  in_mem = True
                  continue
              if in_mem and line and not line[0].isspace():
                  break
              if in_mem:
                  m = re.match(r"^\s+memory_char_limit:\s*(\d+)", line)
                  if m:
                      limits["MEMORY"] = int(m.group(1))
                  m = re.match(r"^\s+user_char_limit:\s*(\d+)", line)
                  if m:
                      limits["USER"] = int(m.group(1))
          return limits

      def split_entries(text: str) -> list[str]:
          return [e.strip() for e in re.split(r"\n?§\n?", text) if e.strip()]

      def notify_once(conflict: Path, message: str) -> None:
          state_path = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermes-brain-conflict-notified.json"
          try:
              seen = json.loads(state_path.read_text(encoding="utf-8"))
          except Exception:
              seen = {}
          key = conflict.name
          mtime = conflict.stat().st_mtime_ns
          if seen.get(key) == mtime:
              return
          seen[key] = mtime
          try:
              state_path.write_text(json.dumps(seen), encoding="utf-8")
          except OSError:
              pass
          subprocess.run(
              ["${pkgs.libnotify}/bin/notify-send", "-u", "normal", "Hermes memory conflict", message],
              check=False,
          )

      limits = read_limits()
      for conflict in conflicts:
          stem = conflict.name.split(".sync-conflict-", 1)[0]
          if stem not in limits:
              notify_once(conflict, f"Unhandled conflict file: {conflict.name}")
              continue

          target = mem_dir / f"{stem}.md"
          base_entries = split_entries(target.read_text(encoding="utf-8", errors="replace")) if target.is_file() else []
          conflict_entries = split_entries(conflict.read_text(encoding="utf-8", errors="replace"))

          merged = list(base_entries)
          for entry in conflict_entries:
              if entry not in merged:
                  merged.append(entry)

          merged_text = "\n§\n".join(merged)
          limit = limits[stem]
          if len(merged_text) > limit:
              msg = f"{conflict.name} exceeds {stem}.md limit ({len(merged_text)}/{limit} chars); merge manually."
              print(msg, file=sys.stderr)
              notify_once(conflict, msg)
              continue

          # Prefix matches Syncthing's .tmp_* ignore pattern during atomic write.
          fd, tmp_name = tempfile.mkstemp(prefix=".tmp_merge_", dir=mem_dir)
          try:
              with os.fdopen(fd, "w", encoding="utf-8") as f:
                  f.write(merged_text)
              os.replace(tmp_name, target)
          except Exception:
              if os.path.exists(tmp_name):
                  os.unlink(tmp_name)
              raise
          conflict.unlink()
          print(f"Merged {conflict.name} into {target.name} ({len(merged_text)}/{limit} chars)")
    '';
  };
in
{
  services.syncthing = {
    # Additive-only so GUI-configured devices and folders survive switches.
    overrideDevices = false;
    overrideFolders = false;

    settings = {
      devices = peers;

      folders.${folderId} = {
        path = "${config.users.users.finn.home}/${brainDir}";
        type = "sendreceive";
        devices = lib.attrNames peers;
        ignorePerms = true;
        ignorePatterns = [
          "*.lock"
          ".tmp_*"
          ".mem_*"
        ];
        versioning = {
          type = "staggered";
          params = {
            maxAge = "2592000";
            cleanInterval = "3600";
          };
        };
      };
    };
  };

  home-manager.users.finn =
    {
      config,
      lib,
      ...
    }:
    let
      homeDir = config.home.homeDirectory;
      brainPath = "${homeDir}/${brainDir}";
      memoriesLink = "${homeDir}/.hermes/memories";
    in
    {
      # Create target dirs before linkGeneration so the symlink never starts dangling.
      home.activation.hermesBrain = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        run mkdir -p ${lib.escapeShellArg "${brainPath}/skills"} \
                     ${lib.escapeShellArg "${brainPath}/memories"}

        if [ -d ${lib.escapeShellArg memoriesLink} ] \
           && [ ! -L ${lib.escapeShellArg memoriesLink} ]; then
          for f in ${lib.escapeShellArg memoriesLink}/*; do
            [ -e "$f" ] || continue
            name="$(basename "$f")"
            case "$name" in
              *.lock|.mem_*) continue ;;
            esac
            dest=${lib.escapeShellArg "${brainPath}/memories"}/"$name"
            if [ ! -e "$dest" ]; then
              run cp -a "$f" "$dest"
            elif [ -f "$f" ] && ! cmp -s "$f" "$dest"; then
              run cp -a "$f" "$dest.local-${self}"
            fi
          done
        fi
      '';

      home.file.".hermes/memories" = {
        source = config.lib.file.mkOutOfStoreSymlink "${brainPath}/memories";
        force = true;
      };

      systemd.user.paths.hermes-brain-conflict-merge = {
        Unit.Description = "Watch Hermes memories for Syncthing conflicts";
        Path.PathChanged = "${brainPath}/memories";
        Install.WantedBy = [ "default.target" ];
      };

      systemd.user.services.hermes-brain-conflict-merge = {
        Unit.Description = "Merge Syncthing conflicts in Hermes memories";
        Service = {
          Type = "oneshot";
          ExecStart = "${mergeConflicts} ${brainPath}/memories ${homeDir}/.hermes/config.yaml";
        };
      };
    };
}
