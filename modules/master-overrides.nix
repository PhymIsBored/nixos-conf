packages:
{ inputs, ... }:

{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        master = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system};
      in
      prev.lib.genAttrs packages (name: master.${name})
    )
  ];
}
