{ pkgs, ... }:

let
  beyondAllReason = pkgs.callPackage ./beyond-all-reason/package.nix { };
in
{
  hardware.graphics.enable = true;

  assertions = [
    {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "The native Beyond All Reason package requires x86_64-linux (the upstream Linux release architecture).";
    }
  ];

  environment.systemPackages = [ beyondAllReason ];
}
