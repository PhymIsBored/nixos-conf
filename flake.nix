{
  description = "Cool nix flake";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      sops-nix,
      ...
    }:
    {
      nixosConfigurations = {
        lapnix = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./base.nix
            ./hosts/laptop/laptop.nix
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
