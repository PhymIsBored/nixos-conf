packages:
{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  paths = map (name: lib.splitString "." name) packages;
in
{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        master = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system};
      in
      lib.updateManyAttrsByPath (map (path: {
        inherit path;
        update = _: lib.getAttrFromPath path master;
      }) paths) prev
    )
  ];

  environment.systemPackages = map (path: lib.getAttrFromPath path pkgs) paths;
}
