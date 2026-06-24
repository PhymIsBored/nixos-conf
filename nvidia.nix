{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    open = true;
    powerManagement.enable = true;
    modesetting.enable = true; # wayland

    nvidiaSettings = true;
  };
}
