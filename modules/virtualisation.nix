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

  # Scope guest DNS/DHCP to libvirt's default NAT bridge instead of all interfaces.
  # Can likely be removed once verified against a running guest (libvirt manages its own rules).
  networking.firewall.interfaces."virbr0" = {
    allowedTCPPorts = [
      53
    ];
    allowedUDPPorts = [
      67
      53
    ];
  };

  environment.systemPackages = with pkgs; [
    virt-viewer
  ];

  users.users.finn.extraGroups = [ "libvirtd" ];
}
