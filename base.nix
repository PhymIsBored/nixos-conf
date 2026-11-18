{
  config,
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./sops.nix
    ./modules/r-lang.nix
    ./modules/niri.nix
    ./modules/hermes-brain.nix
    inputs.hermes-agent.nixosModules.default
  ];

  ## nix ######################################################################
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 5";
    flake = "/home/finn/nixos-conf"; # sets NH_OS_FLAKE variable for you
  };

  ## Bootloader ###############################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## networking ###############################################################
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];

  # firewall
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
  };

  services.resolved.enable = true;

  ## locale ###################################################################
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };
    inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5.addons = with pkgs; [
        fcitx5-anthy
        fcitx5-gtk
        fcitx5-mozc
        fcitx5-nord # a color theme
      ];
    };
  };
  services.xserver.xkb = {
    layout = "de";
    variant = "nodeadkeys";
  };

  console.keyMap = "de-latin1-nodeadkeys";
  environment.variables = {
    XMODIFIERS = "@im=fcitx";
  };

  ## desktop ##################################################################
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  ## printing #################################################################
  services.printing.enable = true;

  ## sound ####################################################################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;

  ## user #####################################################################
  users.users."finn" = {
    isNormalUser = true;
    description = "finn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  ## system packages ##########################################################
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    bluetui
    direnv
    ffmpeg
    foot
    ghostty
    git
    htop
    jq
    kdePackages.partitionmanager
    ldns
    less
    neovim
    openssl
    unzip
    vim
    wget
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  # Prefer Japanese glyph forms when falling back to CJK fonts.
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      "Noto Sans"
      "Noto Sans CJK JP"
    ];
    serif = [
      "Noto Serif"
      "Noto Serif CJK JP"
    ];
    monospace = [
      "Hack"
      "Noto Sans Mono"
      "Noto Sans Mono CJK JP"
    ];
  };

  system.stateVersion = "26.05";

}
