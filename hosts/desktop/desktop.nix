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
    ../../modules/docker.nix
    ../../modules/netbird.nix
    ../../modules/faf.nix
    ../../modules/beyond-all-reason.nix
    ../../modules/bar-native.nix
    ../../modules/virtualisation.nix
    ../../modules/speech-transcription.nix
    ../../modules/speech-tts.nix
  ];

  networking = {
    hostName = "desknix";
    firewall = {
      allowedTCPPorts = [
        1234 # lmstudio
      ];
    };
    interfaces.enp8s0.wakeOnLan.enable = true;
  };

  services.openssh = {
    enable = false;
    openFirewall = false;
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

  programs.faf = {
    enable = true;
    directory = "faf-linux";
  };

  programs.bar-native.enable = true;

  environment.systemPackages = with pkgs; [
    liquidctl
    lm_sensors
    lmstudio
    nvtopPackages.nvidia
  ];
}
