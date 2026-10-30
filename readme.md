[list of external inputs>](external.md)

# Wi-Fi backends

Import exactly one Wi-Fi module in the host configuration:

```nix
imports = [ ../../modules/wifi_iwd.nix ]; # iwd
# imports = [ ../../modules/wifi_wpa.nix ]; # wpa_supplicant
```

Both use NetworkManager and import `modules/networkmanager-profiles.nix` for the
same SOPS-managed Wi-Fi and VPN profiles. NetworkManager and its OpenVPN plugin
are enabled in `base.nix`; the secrets are declared in `sops.nix`.

The iwd module also installs its native profiles and loads `pkcs8_key_parser` for
eduroam. The WPA module selects NetworkManager's `wpa_supplicant` backend and gives
the hardened service read access to the eduroam PEM certificates and private key.
No host-specific settings need changing when switching the import.

Evaluate both backends on both hosts without activating either:

```bash
nix eval --impure --json --file tests/wifi.nix
```

# Setup Sops-nix

1. Generate ssh keys (without passphrase)
```bash
ssh-keygen -t ed25519
```

2. Generate sops private-key from ssh-key
```bash
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt
```

3. Generate sops public-key from private-key
```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

4. Add your public-key to `.sops.yaml`
```yaml
keys:
  - &lapnix age1sxluvsegl5a5f7mv2pnh2y9rqym8tdhdgrwwygz0yk2wljjmlpqs9y9cq2 
  - &<new name here> <your age public key>
creation_rules:
  # binary files
  - path_regex: secrets/[^/]+\.(bin|key|pem|crt|der|p12|pfx|gpg|asc)$
    input_type: binary
    output_type: binary
    key_groups:
      - age:
          - *lapnix
          - *<new name here>

  # supported file types
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini|sops)$
    key_groups:
      - age:
          - *lapnix
          - *<new name here>

```

5. reencrypt the secrets on host that already has secrets
```bash
find ~/nixos-conf/secrets/ -type f -exec sh -c 'sops -d -i "$1" && sops -e -i "$1"' _ {} \;
```

