{ config, pkgs, ... }:
{
  services.syncthing = {
    enable = true;
    user = "finn";
    dataDir = "/home/finn";
    configDir = "/home/finn/.config/syncthing";
    # Opens sync (22000/tcp+udp) and local discovery (21027/udp); GUI stays on 127.0.0.1:8384.
    openDefaultPorts = true;
    #guiAddress = "localhost:8384";
    settings = {
      #devices = {
      #  "device1" = { id = "DEVICE-ID-GOES-HERE"; };
      #  "device2" = { id = "DEVICE-ID-GOES-HERE"; };
      #};
      #folders = {
      #  "Documents" = {
      #    path = "/home/myusername/Documents";
      #    devices = [ "device1" "device2" ];
      #  };
      #  "Example" = {
      #    path = "/home/myusername/Example";
      #    devices = [ "device1" ];
      #    ignorePerms = false; # Enable file permission syncing
      #  };
      #};
    };
  };

  environment.systemPackages = with pkgs; [
    syncthingtray
  ];

}
