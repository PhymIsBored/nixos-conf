{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.bar-lobby;
in
{
  options.programs.bar-lobby = {
    enable = lib.mkEnableOption "the BAR Lobby client for Beyond All Reason";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./bar-lobby/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./bar-lobby/package.nix { }";
      description = ''
        BAR Lobby package to install. By default it is built with the host's
        Nixpkgs, including its configuration and overlays. It does not replace
        pkgs.beyond-all-reason or the existing bar launcher.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
