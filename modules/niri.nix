{ pkgs, ... }:
{
  programs.niri.enable = true;

  # plasma6 and programs.niri both set this with mkDefault; keep plasma as
  # the SDDM default.
  services.displayManager.defaultSession = "plasma";

  environment.systemPackages = with pkgs; [
    noctalia
    xwayland-satellite
  ];
}
