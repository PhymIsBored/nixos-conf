{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./laptop/hardware-configuration.nix
    #./wifi_wpa.nix
    ./wifi_iwd.nix
    # ./nvidia.nix
  ];

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

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "pkcs8_key_parser" ];

  hardware.bluetooth.enable = true;

  networking.hostName = "nix-laptop"; # Define your hostname.

  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/finn/.config/sops/age/keys.txt";
    secrets = {
      "eduroam/identity" = { };
      "eduroam/pk_pass" = { };
      "eduroam/client_cert.p12" = {
        sopsFile = ./secrets/eduroam_client_cert.p12;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/client_cert.crt.pem" = {
        sopsFile = ./secrets/eduroam_client_cert.crt.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/client_cert.key.pem" = {
        sopsFile = ./secrets/eduroam_client_cert.key.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/ca_cert.pem" = {
        sopsFile = ./secrets/eduroam_ca_cert.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "finnsWlan5G/psk" = { };
      "finnsHotspot/psk" = { };
    };
  };

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  hardware.graphics.enable = true;

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "de";
    variant = "nodeadkeys";
  };

  # Configure console keymap
  console.keyMap = "de-latin1-nodeadkeys";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."finn" = {
    isNormalUser = true;
    description = "finn";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      thunderbird
      anki
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    alacritty
    bluetui
    git
    htop
    impala
    less
    neovim
    openssl
    vim
    wget
  ];
  environment.variables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
