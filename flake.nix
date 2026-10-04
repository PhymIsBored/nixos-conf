{
  description = "Cool nix flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    nixpkgs-openvpn3.url = "github:NixOS/nixpkgs/cb7be403c8c89bc290dcb411c8f0e4de854c9feb";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-openvpn3,
      home-manager,
      sops-nix,
      ...
    }:
    let
      openvpn3Module = { pkgs, ... }: {
        nixpkgs.overlays = [
          (final: prev: {
            openvpn3 =
              nixpkgs-openvpn3.legacyPackages.${prev.stdenv.hostPlatform.system}.openvpn3;
          })
        ];

        environment.systemPackages = [ pkgs.openvpn3 ];
      };
    in
    {
      nixosConfigurations = {
        lapnix = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./base.nix
            ./hosts/laptop/laptop.nix
            openvpn3Module
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

        desknix = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./base.nix
            ./hosts/desktop/desktop.nix
            openvpn3Module
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
      };
    };
}
