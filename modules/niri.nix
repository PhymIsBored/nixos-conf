{ pkgs, lib, ... }:
{
  programs.niri.enable = true;

  # plasma6 and programs.niri both set this with mkDefault; keep plasma as
  # the SDDM default.
  services.displayManager.defaultSession = "plasma";

  # KWallet must be the only Secret Service provider: gnome-keyring (enabled by
  # programs.niri.enable with mkDefault) races ksecretd for
  # org.freedesktop.secrets, and its D-Bus activation file lets it start and win
  # at login no matter what PAM does. Without the package nothing can claim the
  # name ahead of ksecretd. gcr-ssh-agent's enable default follows
  # gnome-keyring.enable, so turn it on explicitly; its SSH key then lives in
  # KWallet instead of the gnome login keyring.
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  services.gnome.gcr-ssh-agent.enable = true;

  # Route XDG Secret portal requests under Niri to KWallet instead of
  # gnome-keyring/oo7-portal.
  xdg.portal = {
    extraPortals = [ pkgs.kdePackages.kwallet ];
    config.niri."org.freedesktop.impl.portal.Secret" = lib.mkForce [ "kwallet" ];
  };

  # Unlock KWallet from SDDM's PAM credentials once Niri's Wayland socket is up
  # and before graphical-session.target services can race to D-Bus-activate a
  # non-PAM ksecretd. Bound to niri.service so it never runs under Plasma.
  systemd.user.services.niri-kwallet-pam = {
    description = "Unlock KWallet from PAM credentials (niri)";
    wantedBy = [ "niri.service" ];
    after = [ "niri.service" ];
    before = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
      Slice = "background.slice";
    };
  };

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
