{ config, ... }:
{
  services.syncthing = {
    enable = true;
    openDefaultPorts = false; # not sure what this does
    guiPasswordFile = config.sops.secrets."syncthing-pwd".path;
    #guiAddress = "localhost:8384";
    settings = {
      gui.user = "finn";
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
