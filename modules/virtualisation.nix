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

  networking.firewall = {
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
