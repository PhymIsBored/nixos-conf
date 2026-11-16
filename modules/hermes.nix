{ config, pkgs, ... }:

let
  settings = {
    agent = {
      max_turns = 150;
      reasoning_effort = "max";
      clarify_timeout = 600;
    };
    display = {
      interface = "tui";
      skin = "default";
      show_reasoning = false;
      platforms.cli.show_reasoning = true;
      timestamps = true;
      vim_mode = true;
      busy_input_mode = "queue";
      details_mode = "expanded";
      sections = {
        thinking = "collapsed";
        tools = "expanded";
        subagents = "expanded";
        activity = "expanded";
      };
    };
    model = {
      default = "gwdg.glm-5.3";
      provider = "upb";
      base_url = "https://ai-gateway.uni-paderborn.de/v1";
      api_mode = "chat_completions";
    };
    # UPB AI gateway, mirroring dotfiles/opencode/opencode.jsonc.
    # The key is read from UPB_API_KEY in ~/.hermes/.env (key_env), never from this file.
    providers.upb = {
      base_url = "https://ai-gateway.uni-paderborn.de/v1";
      key_env = "UPB_API_KEY";
      api_mode = "chat_completions";
      default_model = "gwdg.glm-5.3";
    };
    gateway.service_install_choice = "decline";
    # Terminal-text globs block matches even under YOLO, not access through other tools.
    # Broad Git rules also block normal pushes, soft resets, clean dry runs, and mentions.
    approvals = {
      mode = "smart";
      cron_mode = "deny";
      single_query_mode = "deny";
      unattended_mode = "deny";
      deny = [
        "*.ssh/*"
        "*.hermes/.env*"
        "*.env"
        "*.env.*"
        "*git*push*"
        "*git*reset*"
        "*git*clean*"
      ];
    };
    security = {
      redact_secrets = true;
      protected_instruction_files = true;
    };
    # Guardian route: UPB fast model, with OpenRouter Claude Haiku 5.5 as failover.
    # Requires OPENROUTER_API_KEY in ~/.hermes/.env.
    auxiliary.approval = {
      provider = "upb";
      model = "gwdg.deepseek-v4.1-flash-1017";
      timeout = 20;
      fallback_chain = [
        {
          provider = "openrouter";
          model = "anthropic/claude-haiku-5.5";
        }
      ];
    };
    browser.cloud_provider = "local";
    computer_use.backend = "cua";
    video_gen = {
      provider = "openrouter";
      model = "google/veo-3.1-lite";
    };
    platform_toolsets.cli = [
      "browser"
      "clarify"
      "code_execution"
      "computer_use"
      "connections"
      "cronjob"
      "delegation"
      "file"
      "image_gen"
      "memory"
      "session_search"
      "skills"
      "terminal"
      "todo"
      "tts"
      "video"
      "video_gen"
      "vision"
      "web"
    ];
    known_plugin_toolsets.cli = [ "a2a" ];
    known_builtin_toolsets.cli = [
      "browser"
      "clarify"
      "code_execution"
      "computer_use"
      "connections"
      "context_engine"
      "cronjob"
      "delegation"
      "discord"
      "discord_admin"
      "file"
      "image_gen"
      "kanban"
      "memory"
      "session_search"
      "skills"
      "stt"
      "terminal"
      "todo"
      "tts"
      "video"
      "video_gen"
      "vision"
      "web"
      "x_search"
    ];
    onboarding.seen = {
      busy_input_prompt = true;
      tool_progress_prompt = true;
    };
    telemetry.shared_metrics = {
      enabled = false;
      send = false;
      offer_version = 2;
    };
  };
  settingsFile =
    pkgs.runCommand "hermes-settings.json"
      {
        settings = builtins.toJSON settings;
        passAsFile = [ "settings" ];
      }
      ''
        HOME=$TMPDIR ${config.services.hermes-agent.package.hermesVenv}/bin/python3 - "$settingsPath" > "$out" <<'PY'
        import json, sys
        from hermes_cli.config_defaults import DEFAULT_CONFIG

        with open(sys.argv[1]) as f:
            settings = json.load(f)
        settings["_config_version"] = DEFAULT_CONFIG["_config_version"]
        json.dump(settings, sys.stdout)
        PY
      '';
  writeConfig = pkgs.writeScript "write-hermes-config" ''
    #!${pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ])}/bin/python3
    import io, json, os, shutil, sys, tempfile
    from pathlib import Path
    from ruamel.yaml import YAML

    path = Path(sys.argv[1])
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    yaml = YAML()
    yaml.version = (1, 1)
    with open(sys.argv[2]) as f:
        settings = json.load(f)
    rendered = io.StringIO()
    yaml.dump(settings, rendered)
    content = rendered.getvalue().encode("utf-8")
    if path.is_symlink():
        raise SystemExit(f"Refusing to overwrite symlink: {path}")
    if path.exists() and path.read_bytes() == content:
        os.chmod(path, 0o600)
        sys.exit(0)
    if path.exists():
        fd, backup = tempfile.mkstemp(prefix="config.yaml.pre-nix-", dir=path.parent)
        os.close(fd)
        shutil.copyfile(path, backup)
        os.chmod(backup, 0o600)
        print(f"Backed up Hermes config to {backup}")
    fd, temporary = tempfile.mkstemp(prefix=".config.yaml-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(content)
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
  '';
in
{
  # Install the CLI without enabling the upstream system gateway. Credentials,
  # sessions, and OAuth state remain in finn's existing ~/.hermes directory.
  environment.systemPackages = [ config.services.hermes-agent.package ];

  home-manager.users.finn = { lib, ... }: {
    # Activation resets runtime changes to the declarative settings.
    home.activation.hermesConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${writeConfig} "$HOME/.hermes/config.yaml" ${settingsFile}
    '';
  };
}
