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

## BAR Native

Launch it with `bar-native` or the
**Beyond All Reason (Native)** desktop entry. Both the Lobby and its downloaded
engines run outside FHS, using the host graphics driver without forcing X11 or
PRIME offload. The existing `bar` and `bar-lobby` launchers remain installed.

To enable it on another x86_64-linux host:

```nix
imports = [ ../../modules/bar-native.nix ];
programs.bar-native.enable = true;
```

The module and packaging are self-contained under `modules/bar-native.nix` and
`modules/bar-native/`; they do not depend on `/home/finn/bar/bar-native`. The
package uses the host's `pkgs`, with no new flake inputs or Nixpkgs pin. The unfree
assets are covered by the existing policy in `base.nix`.

Close any other BAR Lobby instance before launching. The native Lobby reuses the
existing assets under `$XDG_DATA_HOME/BeyondAllReason/assets` (defaulting to
`~/.local/share/BeyondAllReason/assets`) and state under
`$XDG_STATE_HOME/BeyondAllReason` (defaulting to `~/.local/state/BeyondAllReason`).
Set `BAR_STATE_PATH` for separate settings/state and `BAR_ASSETS_PATH` for separate
content; shared assets remain writable by the Lobby.

`runtime.nix` invokes downloaded engines and `pr-downloader` through Nix's ELF
loader and library paths, without modifying downloaded binaries. The Lobby's
`--isolation` flag is retained: it controls engine content directories, not an FHS
sandbox. `hardware.graphics` is enabled, but the module does not configure the
GPU driver, enable `nix-ld`, or disable Electron's sandbox.

Update the Lobby version and AppImage hash in `modules/bar-native/package.nix`,
not through its in-app updater. `programs.bar-native.package` can override the
package. The build checks the expected upstream child-process imports, so an
upstream bundle change fails rather than silently bypassing the native runtime.

Validate the adapter and build the enabled package without activating the system:

```bash
node --test modules/bar-native/tests/native-spawn.test.cjs
nix build .#nixosConfigurations.desknix.config.programs.bar-native.package --no-link
```

The original standalone package was tested loading a local skirmish through the
Lobby on NVIDIA/Wayland. Actual multiplayer, fresh downloads and extended gameplay
remain untested.
