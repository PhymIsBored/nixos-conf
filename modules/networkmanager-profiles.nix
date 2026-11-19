{ config, pkgs, ... }:
{
  # Shared Wi-Fi and VPN profiles for both NetworkManager Wi-Fi backends.
  sops.templates."eduroam" = {
    content = ''
      [802-1x]
      ca-cert=${config.sops.secrets."eduroam/ca_cert.pem".path}
      client-cert=${config.sops.secrets."eduroam/client_cert.crt.pem".path}
      domain-suffix-match=radius.uni-paderborn.de
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

  sops.templates."Unifi" = {
    content = ''
      [connection]
      id=Unifi
      type=wifi

      [wifi]
      mode=infrastructure
      ssid=Unifi

      [wifi-security]
      key-mgmt=wpa-psk
      psk=${config.sops.placeholder."Unifi/psk"}

      [ipv4]
      method=auto

      [ipv6]
      addr-gen-mode=stable-privacy
      method=auto

      [proxy]
    '';
    path = "/etc/NetworkManager/system-connections/Unifi.nmconnection";
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

      ca=${config.sops.secrets."eduroam/upb_vpn_ca.pem".path}
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
      # Route the university's IPv4 network through the VPN, not all traffic.
      route1=131.234.0.0/16
      never-default=true

      [ipv6]
      method=auto
      # The VPN supplies the university's IPv6 route.
      never-default=true
    '';
    path = "/etc/NetworkManager/system-connections/irb-vpn.nmconnection";
    mode = "0600";
  };

  # connection.autoconnect is not implemented for VPN profiles. Trigger activation
  # asynchronously from a NetworkManager dispatcher hook whenever a physical link
  # comes up, avoiding boot stalls while offline and re-arming after resume/roaming.
  systemd.services.irb-vpn = {
    description = "Uni Paderborn (IRB 509) VPN";
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "irb-vpn-up" ''
        set -euo pipefail
        if ${pkgs.networkmanager}/bin/nmcli -t -f NAME connection show --active \
          | ${pkgs.gnugrep}/bin/grep -Fxq 'Uni Paderborn (IRB 509)'; then
          exit 0
        fi
        exec ${pkgs.networkmanager}/bin/nmcli connection up 'Uni Paderborn (IRB 509)'
      '';
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "irb-vpn-dispatcher" ''
        iface="$1"
        action="$2"

        if [ "$action" != "up" ]; then
          exit 0
        fi

        case "$iface" in
          lo | tun* | tap* | wt* | virbr* | docker* | br-* | veth*)
            exit 0
            ;;
        esac

        if [ "''${CONNECTION_ID:-}" = "Uni Paderborn (IRB 509)" ]; then
          exit 0
        fi

        exec ${pkgs.systemd}/bin/systemctl --no-block start irb-vpn.service
      '';
    }
  ];
}
