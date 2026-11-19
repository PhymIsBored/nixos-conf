{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/finn/.config/sops/age/keys.txt";
    secrets = {
      "eduroam/identity" = { };
      "eduroam/client_cert.crt.pem" = {
        sopsFile = ./secrets/eduroam_client_cert.crt.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/client_cert.key.pem" = {
        sopsFile = ./secrets/eduroam_client_cert.key.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/ca_cert.pem" = {
        sopsFile = ./secrets/eduroam_ca_cert.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "eduroam/upb_vpn_ca.pem" = {
        sopsFile = ./secrets/upb_vpn_ca.pem;
        format = "binary";
        #group = "wpa_supplicant";
        mode = "0640";
      };
      "finnsWlan5G/psk" = { };
      "finnsHotspot/psk" = { };
      "Unifi/psk" = { };
      "anki/username" = {
        owner = "finn";
        mode = "0400";
      };
      "anki/sync-key" = {
        owner = "finn";
        mode = "0400";
      };
    };
  };
}
