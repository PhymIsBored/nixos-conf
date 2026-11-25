{ pkgs, lib, ... }:
{
  # Sway as a second Wayland session next to niri (SDDM lists both; Plasma stays
  # the default session). Sway brings its own XWayland, so games launched here do
  # not go through xwayland-satellite.
  programs.sway = {
    enable = true;

    # `output <name> hdr on` only works with the Vulkan renderer; wlroots calls it
    # experimental, so drop this line (and HDR in dotfiles/sway/config) to get the
    # stable GLES path back.
    extraSessionCommands = ''
      export WLR_RENDERER=vulkan
    '';
  };

  # On top of the sway module's own extraPackages (foot, grim, swayidle, …).
  environment.systemPackages = with pkgs; [
    slurp
    wl-clipboard
    # PaperWM-style scrolling layout on demand, driven by a keybind in
    # dotfiles/sway/config (scroll mode). Not a sway layout: papersway is a
    # daemon that drives placement over sway's IPC.
    perlPackages.Apppapersway
  ];

  # Same keyring routing as niri: only KWallet may answer org.freedesktop.secrets,
  # otherwise the GTK portal backend races ksecretd for the name.
  xdg.portal.config.sway."org.freedesktop.impl.portal.Secret" = lib.mkForce [ "kwallet" ];
}
