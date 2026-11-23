{
  description = "Cool nix flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      sops-nix,
      disko,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            ./base.nix
            hostModule
            disko.nixosModules.disko
            sops-nix.nixosModules.sops

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.finn = import ./home.nix;
              home-manager.backupFileExtension = "backup";
            }
          ];
        };
    in
    {
      formatter.${system} = pkgs.writeShellApplication {
        name = "treefmt";
        runtimeInputs = [
          pkgs.treefmt
          pkgs.nixfmt
          pkgs.ruff
        ];
        text = ''
          exec treefmt "$@"
        '';
      };

      nixosConfigurations = {
        lapnix = mkHost ./hosts/laptop/laptop.nix;
        desknix = mkHost ./hosts/desktop/desktop.nix;
      };
    };
}
