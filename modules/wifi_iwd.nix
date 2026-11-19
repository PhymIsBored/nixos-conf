{ config, ... }:
{
  imports = [
    ./networkmanager-profiles.nix
  ];

  # Required for iwd to read the eduroam PEM private key.
  boot.kernelModules = [ "pkcs8_key_parser" ];

  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.settings = {
    Network.EnableIPv6 = true;
    Settings.AddressRandomization = "network";
    Settings.AddressRandomizationRange = "full";
  };

  # Kept until eduroam is tested on campus with NetworkManager's own iwd provisioning
  # (iwd-config-path=auto); keep pkcs8_key_parser even after removing this template.
  sops.templates."eduroam.8021x" = {
    content = ''
      [Security]
      EAP-Method=TLS
      EAP-TLS-CACert=${config.sops.secrets."eduroam/ca_cert.pem".path}
      EAP-Identity=${config.sops.placeholder."eduroam/identity"}
      EAP-TLS-ClientCert=${config.sops.secrets."eduroam/client_cert.crt.pem".path}
      EAP-TLS-ClientKey=${config.sops.secrets."eduroam/client_cert.key.pem".path}
      EAP-TLS-ServerDomainMask=radius.uni-paderborn.de
    '';
    path = "/var/lib/iwd/eduroam.8021x";
    mode = "0600";
  };
}
