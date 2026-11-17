{ pkgs, ... }:
{
  programs.niri.enable = true;

  # plasma6 and programs.niri both set this with mkDefault; keep plasma as
  # the SDDM default.
  services.displayManager.defaultSession = "plasma";

  # DDC/CI brightness for external monitors (Noctalia's opt-in ddcutil backend).
  # The ddcutil binary alone is useless here: there are no /dev/i2c-* nodes until
  # i2c-dev is loaded, and an unprivileged shell needs an ACL on them.
  # hardware.i2c.enable does both — it loads the module, creates the i2c group
  # and installs a uaccess udev rule (70-i2c.rules) for seat users.
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    ddcutil
    noctalia
    xwayland-satellite
  ];
}
