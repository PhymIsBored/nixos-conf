{ pkgs, ... }:

let
  extraRPackages = with pkgs.rPackages; [
    nycflights13
    palmerpenguins
    rmarkdown
    tidyverse
  ];

  RWithPackages = pkgs.rWrapper.override {
    packages = extraRPackages;
  };

  RStudioWithPackages = pkgs.rstudioWrapper.override {
    packages = extraRPackages;
  };
in
{
  # unstable's rstudio fails to build (hunspell dict collision); master has the
  # fix plus a cached build
  imports = [
    (import ./master-overrides.nix [ "rstudio" "rstudioWrapper" ] { addToSystemPackages = false; })
  ];

  environment.systemPackages = [
    RWithPackages
    RStudioWithPackages
  ];
}
