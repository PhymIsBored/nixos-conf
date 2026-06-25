{ config, ... }:
{
  systemd.services.wpa_supplicant.serviceConfig.BindReadOnlyPaths = [
    "/run/secrets"
    "/run/secrets.d"
  ];

  sops.templates."eduroam" = {
    content = ''
      [802-1x]
      ca-cert=${config.sops.secrets."eduroam/ca_cert.pem".path}
      client-cert=${config.sops.secrets."eduroam/client_cert.p12".path}
      subject-match=radius.uni-paderborn.de
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

  sops.templates."finnsWlan5G" = {
    content = ''
      [connection]
      id=Finns Wlan_5G
      type=wifi

      [wifi]
      mode=infrastructure
      ssid=Finns Wlan_5G

      [wifi-security]
      key-mgmt=sae
      psk=${config.sops.placeholder."finnsWlan5G/psk"}

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=stable-privacy
      ip6-privacy=2
      method=auto
    '';
    path = "/etc/NetworkManager/system-connections/finnsWlan5G.nmconnection";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  sops.templates."finnsHotspot" = {
    content = ''
      [connection]
      id=Finn's Hotspot
      type=wifi

      [wifi]
      mode=infrastructure
      ssid=Finn's Hotspot

      [wifi-security]
      auth-alg=open
      key-mgmt=wpa-psk
      psk=${config.sops.placeholder."finnsHotspot/psk"}

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=default
      method=auto
    '';
    path = "/etc/NetworkManager/system-connections/finnsHotspot.nmconnection";
    owner = "root";
    group = "root";
    mode = "0600";
  };
}
