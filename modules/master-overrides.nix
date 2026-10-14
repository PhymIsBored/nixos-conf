{ inputs, ... }:

{
  nixpkgs.overlays = [
    (
      final: prev:
      let
        master = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system};

        packages = [
          # Overwrite these packages with the newest version from the master branch
          "rstudio"
        ];
      in
      prev.lib.genAttrs packages (name: master.${name})
    )
  ];
}
