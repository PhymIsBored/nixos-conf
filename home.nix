{
  config,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/nixos-conf/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
  configs = {
    alacritty = "alacritty";
    nvim = "nvim";
    opencode = "opencode";
    mpv = "mpv";
  };
in
{
  home.username = "finn";
  home.homeDirectory = "/home/finn";
  home.stateVersion = "26.05";

  ## config files ###############################################################

  xdg.configFile = builtins.mapAttrs (name: subpath: {
    source = create_symlink "${dotfiles}/${subpath}";
    recursive = true;
  }) configs;

  ## programs ###################################################################
  programs.anki = {
    enable = true;
    language = "en_US";
    theme = "dark";
    addons = with pkgs.ankiAddons; [
      review-heatmap
      fsrs4anki-helper
      image-occlusion-enhanced
      # (pkgs.anki-utils.buildAnkiAddon (finalAttrs: {
      #   pname = "kanji-colorizer";
      #   version = "0.10";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "cayennes";
      #     repo = "kanji-colorize";
      #     rev = "1cb34055cd1be470de3be365cf15d3e404762acd";
      #     hash = "sha256-QHBhhr5J6Nu08AaH2TnLzVYEQuaWhedVEfN+UUrbGHU=";
      #   };
      #   sourceRoot = "${finalAttrs.src.name}/";
      # }))
    ];
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
    audacity
    brave
    btop
    calibre
    clock-rs
    densify # wrapper around ghostscript
    gcc
    ghostscript
    gimp
    jellyfin-desktop
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
    opencode
    openvpn3
    pdfarranger
    python3
    ripgrep
    shellcheck
    shfmt
    signal-desktop
    sops
    spotify
    thunderbird
  ];
}
