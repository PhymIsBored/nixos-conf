{ pkgs, ... }:

{
  environment.systemPackages = with pkgs.rPackages; [
    tidyverse
    rmarkdown
    palmerpenguins
    nycflights13
  ];
}
