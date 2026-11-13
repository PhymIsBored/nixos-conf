{ config, pkgs, ... }:

let
  settings = {
    _config_version = 53;
    agent = {
      max_turns = 150;
      reasoning_effort = "medium";
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
    };
    model = {
      default = "gwdg.deepseek-v4.1-flash-1017";
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
      models = {
        "anthropic.claude-opus-5-5".context_length = 1000000;
        "anthropic.claude-haiku-5-5".context_length = 1000000;
        "openai.gpt-6-astra".context_length = 922000;
        "openai.gpt-6.1-sol".context_length = 922000;
        "openai.gpt-6.1-terra".context_length = 922000;
        "openai.gpt-6-luna".context_length = 922000;
        "hs-de.qwen3.8-27b".context_length = 262000;
        "gwdg.glm-5.3-flash".context_length = 200000;
        "gwdg.glm-5.3".context_length = 1000000;
        "gwdg.mistral-large-4-1t-a52b".context_length = 1000000;
        "gwdg.deepseek-v4.1-flash-1017".context_length = 1000000;
      };
    };
    gateway.service_install_choice = "decline";
    # Approval policy, mirroring the opencode permission posture in
    # dotfiles/opencode/opencode.jsonc: prompt for anything risky (manual),
    # hard-deny SSH keys, env/secret files, and history-rewriting git ops.
    # Fnmatch globs, case-insensitive, matched against the whole terminal
    # command; blocks even with --yolo. Test: hermes approvals test -- <cmd>
    approvals = {
      mode = "manual";
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
    browser.cloud_provider = "local";
    computer_use.backend = "cua";
    video_gen = {
      provider = "openrouter";
      model = "google/gemini-omni-1.2-flash";
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
