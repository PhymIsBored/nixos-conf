{ pkgs, ... }:

let
  steamWithFaf = pkgs.steam.override {
    extraPkgs =
      p: with p; [
        git
        curl
        jq
        bubblewrap
        xorg.libXtst
        gtk3
      ];
  };
in
{
  # Requires your GPU driver to be configured as usual.
  # Steam normally enables these already; explicit for clarity.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.steam = {
    enable = true;
    package = steamWithFaf;
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
    steamWithFaf.run

    mangohud
    protontricks
    protonup-qt
    r2modman
  ];
}
