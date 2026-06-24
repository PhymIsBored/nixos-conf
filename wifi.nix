{ config, ... }:
{
  sops.templates."eduroam" = {
    content = ''
      [802-1x]
      ca-cert=${config.sops.secrets."eduroam/ca_cert.pem".path}
      client-cert=${config.sops.secrets."eduroam/client_cert.p12".path}
      domain-suffix-match=radius.uni-paderborn.de
      eap=tls
      identity=${config.sops.placeholder."eduroam/identity"}
      private-key=${config.sops.secrets."eduroam/client_cert.p12".path}
      private-key-password=${config.sops.placeholder."eduroam/pk_pass"}

      [connection]
      id=eduroam
      type=wifi

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=stable-privacy
      ip6-privacy=2
      method=auto

      [wifi]
      mode=infrastructure
      ssid=eduroam

      [wifi-security]
      key-mgmt=wpa-eap
    '';
    path = "/etc/NetworkManager/system-connections/eduroam.nmconnection";
    owner = "root";
    group = "root";
    mode = "0600";
  };
}
