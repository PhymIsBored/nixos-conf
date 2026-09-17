{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
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
    r2modman
    mangohud
    protontricks
    protonup-qt
  ];
}
