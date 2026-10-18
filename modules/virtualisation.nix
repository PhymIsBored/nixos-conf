{ pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;

    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
    };
  };

  programs.virt-manager.enable = true;
  programs.dconf.enable = true;

  # Redirect USB devices into guests using SPICE.
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = [
    pkgs.virt-viewer
  ];

  users.users.finn.extraGroups = [ "libvirtd" ];
}
