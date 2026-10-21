{ pkgs, ... }:

{
  imports = [
    ./r-packages.nix
    #(import ./master-overrides.nix ["rstudio"])
  ];

  environment.systemPackages = with pkgs; [
    R
    rstudio
  ];
}
