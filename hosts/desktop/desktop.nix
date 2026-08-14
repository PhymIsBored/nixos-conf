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

  networking = {
    hostName = "desknix";
    firewall = {
      allowedTCPPorts = [
        1234 # lmstudio
      ];
      allowedUDPPorts = [
        9 # wake-on-lan
      ];
    };
    interfaces.enp8s0.wakeOnLan.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "finn" ];
      MaxAuthTries = 3;
      PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
    };
  };

  programs.coolercontrol.enable = true;
  boot.kernelModules = [ "nct6687" ]; # ASROCK B850 livemixer wifi fan control chip
  boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];
  # The NCT6686D I/O range is reserved by the board's ACPI firmware.
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  environment.systemPackages = with pkgs; [
    liquidctl
    lm_sensors
    lmstudio
    nvtopPackages.nvidia
  ];

  # Disable the GNOME3/GDM auto-suspend feature that cannot be disabled in GUI!
  # If no user is logged in, the machine will power down after 20 minutes.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
