{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    #../../modules/wifi_wpa.nix
    ../../modules/wifi_iwd.nix
  ];

  boot.kernelModules = [ "pkcs8_key_parser" ];

  hardware.bluetooth.enable = true;

  networking.hostName = "lapnix"; # Define your hostname.

  environment.systemPackages = with pkgs; [
    bluetui
  ];

}

