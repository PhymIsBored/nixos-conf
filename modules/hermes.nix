{ config, pkgs, ... }:

let
  settings = {
    _config_version = 53;
    agent = {
      max_turns = 150;
      reasoning_effort = "max";
      clarify_timeout = 600;
    };
    display = {
      interface = "tui";
      skin = "default";
      show_reasoning = false;
      timestamps = true;
      vim_mode = true;
      show_cost = true;
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
    # Approval policy: an auxiliary LLM classifies flagged commands (smart),
    # with uncertain cases escalating to a manual prompt. Hard-deny SSH keys,
    # env/secret files, and history-rewriting git ops regardless of mode.
    # Fnmatch globs, case-insensitive, matched against the whole terminal
    # command; blocks even with --yolo. Test: hermes approvals test -- <cmd>
    approvals = {
      mode = "smart";
      deny = [
        "*.ssh/*" # any command touching SSH keys/config
        "*.hermes/.env*" # hermes's own secret store
        "*.env" # project env files
        "*.env.*"
        "*git push --force*"
        "*git push -f *"
        "*git reset --hard*"
        "*git clean -f*"
      ];
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
    telemetry.shared_metrics = {
      enabled = false;
      send = false;
      offer_version = 2;
    };
  };
  settingsFile = pkgs.writeText "hermes-settings.json" (builtins.toJSON settings);
  mergeConfig = pkgs.writeScript "merge-hermes-config" ''
    #!${pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ])}/bin/python3
    import json, os, shutil, sys, tempfile
    from pathlib import Path
    from ruamel.yaml import YAML

    path = Path(sys.argv[1])
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    yaml = YAML()
    yaml.version = (1, 1)
    with open(sys.argv[2]) as f:
        settings = json.load(f)
    if path.is_symlink():
        raise SystemExit(f"Refusing to overwrite symlink: {path}")
    if path.exists():
        with path.open() as f:
            current = yaml.load(f) or {}
    else:
        current = {}
    if not isinstance(current, dict):
        raise SystemExit(f"Expected a YAML mapping in {path}")

    def merge(base, values):
        for key, value in values.items():
            if isinstance(value, dict) and isinstance(base.get(key), dict):
                merge(base[key], value)
            else:
                base[key] = value

    before = json.dumps(current, sort_keys=True, default=str)
    merge(current, settings)
    if path.exists() and before == json.dumps(current, sort_keys=True, default=str):
        sys.exit(0)
    if path.exists():
        fd, backup = tempfile.mkstemp(prefix="config.yaml.pre-nix-", dir=path.parent)
        os.close(fd)
        shutil.copyfile(path, backup)
        os.chmod(backup, 0o600)
        print(f"Backed up Hermes config to {backup}")
    fd, temporary = tempfile.mkstemp(prefix=".config.yaml-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as f:
            yaml.dump(current, f)
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
    home.activation.hermesConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${mergeConfig} "$HOME/.hermes/config.yaml" ${settingsFile}
    '';
  };
}
