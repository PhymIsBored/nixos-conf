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
  environment.systemPackages = [
    RWithPackages
    RStudioWithPackages
  ];
}
