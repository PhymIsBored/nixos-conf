# Shared agent brain: Hermes skills and long-term memory, kept in sync between
# the NixOS hosts by Syncthing. Nothing here is host-specific except the device
# IDs; every host that includes this module gets the same behaviour.
#
#   1. ~/.hermes-brain/{skills,memories} exist on every host (home-manager).
#   2. ~/.hermes/memories is a symlink into that directory, so MEMORY.md and
#      USER.md are read and written in the synced copy with no rebuild and no
#      commit.
#   3. ~/.hermes-brain is a Syncthing folder shared with every other host in
#      deviceIds. Device names are networking.hostName, so a host never lists
#      itself and never needs to accept the folder by hand.
#
# The skills half needs no Nix: dotfiles/hermes/config.yaml points Hermes at
# ~/.hermes-brain/skills through skills.create_dir.
{ config, lib, ... }:
let
  folderId = "hermes-brain";
  brainDir = ".hermes-brain";

  # Syncthing device IDs of the NixOS hosts. Add a line here and every other
  # host starts sharing the brain with the new one; a host not listed still
  # gets the folder, it just cannot be shared to until its ID is added.
  deviceIds = {
    lapnix = {
      id = "RQ7B7OA-6WTCGAK-K5EN7HD-FDOHPB6-3KAEYNH-DKBZB2J-MX7IHDT-MEOCWQ7";
    };
    desknix = {
      id = "UUFGIHM-GHE6EKF-UEVIXNE-Y5YRVHI-4FNK2SL-4BGIP5G-SCQSZST-TBLMIAK";
      introducer = true;
    };
  };

  self = config.networking.hostName;
  peers = removeAttrs deviceIds [ self ];
in
{
  services.syncthing = {
    # This module only adds. Both options default to true, which would delete
    # the folders and devices configured in the GUI (backup, the vault, the
    # phones) on the first switch.
    overrideDevices = false;
    overrideFolders = false;

    settings = {
      devices = peers;

      folders.${folderId} = {
        path = "~/${brainDir}";
        type = "sendreceive";
        devices = lib.attrNames peers;
        # Memory files are 0600 on one side and 0644 after a git checkout;
        # syncing modes would flap forever.
        ignorePerms = true;
        ignorePatterns = [
          "*.lock"
          ".tmp_*"
          ".mem_*"
        ];
        # Replaces "git revert" for agent-written files: 30 days of per-file
        # history in .stversions.
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
      # Hermes creates ~/.hermes/memories itself, but a dangling symlink makes
      # that mkdir fail with EEXIST, so the target directory has to exist before
      # linkGeneration swaps the symlink in.
      home.activation.hermesBrain = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        run mkdir -p ${lib.escapeShellArg "${brainPath}/skills"} \
                     ${lib.escapeShellArg "${brainPath}/memories"}

        # Preserve any existing local memories before linkGeneration backs up
        # ~/.hermes/memories and replaces it with the symlink.
        if [ -d ${lib.escapeShellArg memoriesLink} ] \
           && [ ! -L ${lib.escapeShellArg memoriesLink} ]; then
          for f in ${lib.escapeShellArg memoriesLink}/*; do
            [ -e "$f" ] || continue
            name="$(basename "$f")"
            case "$name" in
              *.lock|.mem_*) continue ;;
            esac
            if [ ! -e ${lib.escapeShellArg "${brainPath}/memories"}/"$name" ]; then
              run cp -a "$f" ${lib.escapeShellArg "${brainPath}/memories"}/"$name"
            fi
          done
        fi
      '';

      home.file.".hermes/memories" = {
        source = config.lib.file.mkOutOfStoreSymlink "${brainPath}/memories";
        force = true;
      };
    };
}
