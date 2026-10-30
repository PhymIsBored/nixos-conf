# Modules

[< back to readme](readme.md)

## Wi-Fi backends

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

## BAR Lobby

The new BAR Lobby is enabled on `desknix`. Launch it with `bar-lobby` or the
**Beyond All Reason (BAR Lobby)** desktop entry. The existing `bar` command and
`modules/beyond-all-reason.nix` remain unchanged.

To enable it on another host, add the module to that host's `imports` and enable it:

```nix
imports = [ ../../modules/bar-lobby.nix ];
programs.bar-lobby.enable = true;
```

Importing the module alone does not install it. Its package uses the host's `pkgs`
(currently the root flake's `nixos-unstable` input), without a separate Nixpkgs pin
or an overlay replacing the existing BAR package. The bundled assets require
unfree packages to be allowed, as they already are in `base.nix`.

Update the lobby version and AppImage hash in `modules/bar-lobby/package.nix`, not
through its in-app updater. `programs.bar-lobby.package` can override the package
for an individual host.
