[List of external inputs >](external.md)

[Module documentation >](modules.md)

# Formatting and Git hooks

Home Manager installs the formatters and Betterleaks and enables the pre-commit hook for `~/nixos-conf`. The hook formats staged Nix and Python files with treefmt and scans staged changes with Betterleaks. If formatting changes files, review and stage the changes before retrying the commit.

Run `treefmt` or `nix fmt` to format configured files in the working tree. A clone at a different path needs its own hook configuration.

# Setup Sops-nix

1. Generate a dedicated age key (keep SSH keys separate and passphrase-protected)
```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age
nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

2. Print the age public key
```bash
nix shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
```

3. Add your public key to `.sops.yaml`
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

4. Re-encrypt the secret data keys on a host that already has access (without writing plaintext to disk)
```bash
find ~/nixos-conf/secrets/ -type f -exec sops updatekeys -y {} +
```
