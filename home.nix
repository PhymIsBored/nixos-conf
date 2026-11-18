{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/nixos-conf/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  # Chromium infers its secret-service backend from XDG_CURRENT_DESKTOP; under
  # niri it falls back to basic_text and cannot decrypt Signal's kwallet6 key.
  signal-desktop-kwallet = pkgs.symlinkJoin {
    name = "signal-desktop";
    paths = [ pkgs.signal-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop --add-flags "--password-store=kwallet6"
    '';
  };
  configs = {
    alacritty = "alacritty";
    foot = "foot";
    ghostty = "ghostty";
    niri = "niri";
    noctalia = "noctalia";
    nvim = "nvim";
    opencode = "opencode";
    mpv = "mpv";
    yazi = "yazi";
  };
in
{
  home.username = "finn";
  home.homeDirectory = "/home/finn";
  home.stateVersion = "26.05";

  ## config files ###############################################################

  xdg.configFile =
    builtins.mapAttrs (name: subpath: {
      source = create_symlink "${dotfiles}/${subpath}";
      recursive = true;
    }) configs
    // {
      # use mpv conf for jellyfin-mpv-shim
      "jellyfin-mpv-shim/mpv.conf".source = create_symlink "${dotfiles}/mpv/mpv.conf";
      "jellyfin-mpv-shim/input.conf".source = create_symlink "${dotfiles}/mpv/input.conf";
      "jellyfin-mpv-shim/scripts".source = create_symlink "${dotfiles}/mpv/scripts";
      "jellyfin-mpv-shim/script-opts".source = create_symlink "${dotfiles}/mpv/script-opts";
      "jellyfin-mpv-shim/fonts".source = create_symlink "${dotfiles}/mpv/fonts";
    };

  home.file.".hermes/config.yaml".source = create_symlink "${dotfiles}/hermes/config.yaml";
  # Only these non-secret Antigravity settings are managed; keep auth and state local.
  home.file.".gemini/config/config.json".source =
    create_symlink "${dotfiles}/gemini/config/config.json";
  home.file.".gemini/config/hooks.json".source =
    create_symlink "${dotfiles}/gemini/config/hooks.json";
  home.file.".gemini/config/hooks".source =
    create_symlink "${dotfiles}/gemini/config/hooks";
  home.file.".gemini/antigravity-cli/settings.json".source =
    create_symlink "${dotfiles}/gemini/antigravity-cli/settings.json";

  ## programs ###################################################################
  programs.anki = {
    enable = true;
    package = pkgs.anki;
    language = "en_US";
    theme = "dark";
    addons = with pkgs.ankiAddons; [
      review-heatmap
      fsrs4anki-helper
      image-occlusion-enhanced
      (pkgs.anki-utils.buildAnkiAddon (finalAttrs: {
        pname = "kanji-colorizer";
        # To update: pin src.rev to the latest main commit at
        # https://github.com/cayennes/kanji-colorize and update version's date
        # (and upstream version from pavement.py, if changed). Set src.hash to
        # pkgs.lib.fakeHash, rebuild, then replace it with the reported "got" hash.
        # Also check kanjicolorizer/data/kanjivg at that commit: if its submodule
        # revision changed, update kanjiVG.rev and regenerate its hash the same way.
        # Rebuild with: nix build --no-link .#nixosConfigurations.lapnix.config.home-manager.users.finn.home.activationPackage
        version = "0.12-unstable-2026-07-30";
        src = pkgs.fetchFromGitHub {
          owner = "cayennes";
          repo = "kanji-colorize";
          rev = "f0a65bc8d7826f3485909d08fa65a9d280d08400";
          hash = "sha256-YxKMPn0+MZKKz0KHJLPHJQxYsIajYpuzwgWEUaHZt9I=";
        };
        # Fetch the pinned submodule over HTTPS (upstream uses an SSH URL).
        kanjiVG = pkgs.fetchFromGitHub {
          owner = "KanjiVG";
          repo = "kanjivg";
          rev = "93934ee1e4a0e37cda6f19ac111208d5327b1d9e";
          hash = "sha256-hJbaXHsoxkXDuoRQHzCDhXycCyqhyVRh5WZe4eMgUd0=";
        };
        sourceRoot = "${finalAttrs.src.name}/anki";
        # Upstream's release bundles the library and its KanjiVG submodule
        # alongside the Anki entry point; neither is in anki/ itself.
        postUnpack = ''
          cp -r "$sourceRoot/../kanjicolorizer" "$sourceRoot/kanjicolorizer"
          chmod -R u+w "$sourceRoot/kanjicolorizer"
          mkdir -p "$sourceRoot/kanjicolorizer/data/kanjivg"
          cp -r "$kanjiVG/kanji" "$sourceRoot/kanjicolorizer/data/kanjivg/kanji"
          cp -r "$sourceRoot/../licenses" "$sourceRoot/kanjicolorizer/licenses"
          chmod -R u+w "$sourceRoot/kanjicolorizer"
        '';
      }))
    ];
    profiles."finn".sync = {
      # Keep the sync username and key outside Anki's Home Manager-managed,
      # read-only prefs21.db. The sync key is a token, NOT the account password.
      usernameFile = osConfig.sops.secrets."anki/username".path;
      keyFile = osConfig.sops.secrets."anki/sync-key".path;
    };
  };

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ./dotfiles/bash/bashrc;
    sessionVariables = {
      EDITOR = "vim";
    };
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "ui.systemUsesDarkTheme" = 1;
        "browser.theme.content-theme" = 2; # 0: Dark, 1: Light, 2: System
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        "general.autoScroll" = true;
        "sidebar.verticalTabs" = true;
        "sidebar.verticalTabs.dragToPinPromo.dismissed" = true;
        "sidebar.visibility" = "expand-on-hover";
      };
    };
    policies = {
      ExtensionSettings =
        with builtins;
        let
          extension = shortId: uuid: {
            name = uuid;
            value = {
              install_url = "https://addons.mozilla.org/firefox/downloads/latest/${shortId}/latest.xpi";
              installation_mode = "normal_installed";
            };

          };

        in
        listToAttrs [
          (extension "bitwarden-password-manager" "{446900e4-71c2-419f-a6a7-df9c091e268b}")
          (extension "darkreader" "addon@darkreader.org")
          (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
          (extension "ublock-origin" "uBlock0@raymondhill.net")
          (extension "videospeed" "{7be2ba16-0f1e-4d93-9ebc-5164397477a9}")
        ];
    };
  };

  programs.git = {
    enable = true;
    settings = {
      core.pager = "less -R";
    };
    includes = [
      {
        condition = "gitdir:${config.home.homeDirectory}/nixos-conf/.git";
        contents.hook."pre-commit.pre-commit" = {
          event = "pre-commit";
          command = "${pkgs.pre-commit}/bin/pre-commit hook-impl --hook-type pre-commit --";
        };
      }
    ];
  };

  programs.vesktop = {
    enable = true;

    vencord.settings = {
      autoUpdate = true;
      autoUpdateNotification = true;
      notifyAboutUpdates = true;

      plugins = {
        ClearURLs.enabled = true;
        FixYoutubeEmbeds.enabled = true;
      };
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs; # Allow vscode to manage itself, for settigns sync
  };

  ## packages ###################################################################
  home.packages = with pkgs; [
    antigravity-cli
    antigravity-hub
    audacity
    betterleaks
    btop
    calibre
    chromium
    clock-rs
    darktable
    densify # wrapper around ghostscript
    euro-office-desktopeditors
    gcc
    ghostscript
    gimp
    osConfig.services.hermes-agent.package
    jellyfin-mpv-shim
    josm
    julia
    libjxl
    libreoffice
    mpv
    naps2
    neovim
    nil
    nixfmt
    nixpkgs-fmt
    nodejs
    obsidian
    openai-whisper
    opencode
    openvpn3
    pandoc
    pdfarranger
    pre-commit
    python3
    ripgrep
    ruff
    shellcheck
    shfmt
    signal-desktop-kwallet
    sops
    spotify
    thunderbird
    treefmt
    yazi
  ];
}
