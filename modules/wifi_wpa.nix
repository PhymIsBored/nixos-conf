{ lib, ... }:
{
  imports = [
    ./networkmanager-profiles.nix
  ];

  # NetworkManager enables and controls wpa_supplicant over D-Bus.
  networking.networkmanager.wifi.backend = "wpa_supplicant";

  # The hardened service runs as wpa_supplicant, not root.
  sops.secrets =
    lib.genAttrs
      [
        "eduroam/ca_cert.pem"
        "eduroam/client_cert.crt.pem"
        "eduroam/client_cert.key.pem"
      ]
      (_: {
        group = "wpa_supplicant";
        mode = "0640";
      });

  # Expose both the secrets symlink and its generation directory in the sandbox.
  systemd.services.wpa_supplicant.serviceConfig.BindReadOnlyPaths = [
    "/run/secrets"
    "/run/secrets.d"
  ];
}
