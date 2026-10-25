{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    localNetworkGameTransfers.openFirewall = true;
    remotePlay.openFirewall = true;
  };

  programs.gamescope = {
    enable = true;
    enableWsi = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  environment.systemPackages = with pkgs; [
    mangohud
    protontricks
    protonup-qt
    r2modman
  ];
}
