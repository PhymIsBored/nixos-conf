{
  config,
  pkgs,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/nixos-conf/dotfiles";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in
{
  home.username = "finn";
  home.homeDirectory = "/home/finn";
  home.stateVersion = "26.05";

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ./dotfiles/bash/bashrc;
    sessionVariables = {
      EDITOR = "vim";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      core.pager = "less -R";
    };
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

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs; # Allow vscode to manage itself, for settigns sync
  };

  xdg.configFile."qtile" = {
    source = create_symlink "${dotfiles}/qtile/";
    recursive = true;
  };
  xdg.configFile."nvim" = {
    source = create_symlink "${dotfiles}/nvim/";
    recursive = true;
  };

  home.packages = with pkgs; [
    anki
    btop
    calibre
    gcc
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
    openvpn3
    python3
    ripgrep
    shellcheck
    shfmt
    signal-desktop
    sops
    thunderbird
  ];
}
