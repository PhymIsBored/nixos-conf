{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nvidia.nix
    ../../modules/wifi_iwd.nix
    ../../modules/steam.nix
    ../../modules/syncthing.nix
  ];

  networking.hostName = "desknix";
  networking.firewall = {
    allowedTCPPorts = [
      1234  # lmstudio
    ];
  };

  environment.systemPackages = with pkgs; [
    lmstudio
    nvtopPackages.nvidia
    opencode
  ];

  # Disable the GNOME3/GDM auto-suspend feature that cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
