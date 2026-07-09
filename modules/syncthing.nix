{ config, ... }:
{
  services.syncthing = {
    enable = true;
    user = "finn";
    dataDir = "/home/finn";
    configDir = "/home/finn/.config/syncthing";
    openDefaultPorts = false; # not necessary for local gui
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

}
