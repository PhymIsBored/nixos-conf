{ config, ... }:
{
  # make sure kernelModule pkcs8_key_parser is loaded for eduroam with boot.kernelModules = [ "pkcs8_key_parser" ];
  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.settings = {
    Network.EnableIPv6 = true;
    Settings.AutoConnect = true;
    Settings.AddressRandomization = "network";
    Settings.AddressRandomizationRange = "full";
  };

  ## NetworkManager #####################################################################
  sops.templates."eduroam" = {
    content = ''
      [802-1x]
      ca-cert=${config.sops.secrets."eduroam/ca_cert.pem".path}
      client-cert=${config.sops.secrets."eduroam/client_cert.crt.pem".path}
      subject-match=radius.uni-paderborn.de
      eap=tls
      identity=${config.sops.placeholder."eduroam/identity"}
      private-key=${config.sops.secrets."eduroam/client_cert.key.pem".path}

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
    mode = "0600";
  };

  sops.templates."irb-vpn" = {
    content = ''
      [connection]
      id=Uni Paderborn (IRB 509)
      type=vpn
      autoconnect=false
      permissions=

      [vpn]
      auth=SHA512

      ca=${config.sops.secrets."eduroam/ca_cert.pem".path}
      cert=${config.sops.secrets."eduroam/client_cert.crt.pem".path}
      key=${config.sops.secrets."eduroam/client_cert.key.pem".path}


      challenge-response-flags=2
      connection-type=tls
      dev=tun
      push-peer-info=yes
      remote=509.vpn.uni-paderborn.de:1194:udp
      remote-cert-tls=server
      tunnel-mtu=1300
      verify-x509-name=name:509.vpn.uni-paderborn.de
      service-type=org.freedesktop.NetworkManager.openvpn


      [ipv4]
      method=auto
      never-default=true

      [ipv6]
      method=auto
      never-default=true
    '';
    path = "/etc/NetworkManager/system-connections/irb-vpn.nmconnection";
    mode = "0600";
  };

  ## IWD ################################################################################
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

  sops.templates."finnsWlan5G.psk" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."finnsWlan5G/psk"}
    '';
    path = "/var/lib/iwd/finnsWlan5G.psk";
    mode = "0600";
  };

  sops.templates."finnsHotspot.psk" = {
    content = ''
      [Security]
      Passphrase=${config.sops.placeholder."finnsHotspot/psk"}
    '';
    path = "/var/lib/iwd/finnsHotspot.psk";
    mode = "0600";
  };

}
