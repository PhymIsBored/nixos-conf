{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.bar-native;
in
{
  options.programs.bar-native = {
    enable = lib.mkEnableOption "Beyond All Reason with a native, non-FHS engine runtime";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./bar-native/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./bar-native/package.nix { }";
      description = ''
        Native BAR Lobby package to install. By default it uses the host's
        Nixpkgs, including its configuration and overlays. It does not replace
        the existing bar or bar-lobby launchers.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "programs.bar-native requires x86_64-linux (the upstream Linux release architecture).";
      }
    ];
    hardware.graphics.enable = true;
    environment.systemPackages = [ cfg.package ];
  };
}
