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
    ../../modules/docker.nix
  ];

  networking.hostName = "desknix";
  networking.firewall = {
    allowedTCPPorts = [
      1234  # lmstudio
    ];
  };

  programs.coolercontrol.enable = true;
  boot.kernelModules = [ "nct6683" "nct6687d" ]; # ASROCK B850 livemixer wifi fan control chip
  boot.extraModulePackages = [ pkgs.linuxPackages.nct6687d ];

  environment.systemPackages = with pkgs; [
    liquidctl
    lm_sensors
    lmstudio
    nvtopPackages.nvidia
    linuxPackages_latest.nct6687d
  ];

  # Disable the GNOME3/GDM auto-suspend feature that cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
