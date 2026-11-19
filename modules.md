# Modules

[< back to readme](readme.md)

## Local transcription

`modules/speech-transcription.nix` installs `transcribe` on the desktop:

```bash
transcribe speed recording.webm --format srt --output recording.srt
transcribe accuracy recording.webm --language Japanese --format srt --output recording.srt
transcribe accuracy recording.webm --language English --format json --output recording.json
```

`speed` uses Parakeet TDT 0.6B v3 int8 (25 European languages) with a pinned,
CUDA-enabled sherpa-onnx binary. `accuracy` uses the original Qwen3-ASR **1.7B**
checkpoint in BF16 on CUDA. GPU is the default; `--device cpu` is explicit.
The command rejects detected CUDA-to-CPU fallback instead of silently continuing.
Some ONNX operators can still run on CPU within an otherwise GPU session.

Outputs: `text`, `json` (word spans and subtitle cues), `srt`, and `vtt`.
Parakeet returns native token timings, grouped into words. Qwen uses the separate
Qwen3-ForcedAligner 0.6B for timestamped formats; this is not the smaller ASR
model. Japanese and English alignment are supported, but the aligner does not
cover every Qwen ASR language. Cue boundaries use actual model timings, not
fixed chunk durations. Japanese cue text follows the aligner's tokenization,
which can remove punctuation.

`--limit-seconds 60` provides a short test. Audio is processed in 60-second chunks
by default (`--chunk-seconds 1..120`), with absolute timestamps across chunks.
Chunks do not overlap, so a word crossing a boundary can be lost or split.
Speaker labels/diarization are not included.

The Qwen runtime uses a Nix FHS environment and hash-locked Python wheels from
`modules/speech-requirements.lock`, not a fully Nix-store-built Python closure.
First accuracy use installs the pinned environment under
`${XDG_DATA_HOME:-~/.local/share}/transcription/qwen-venv` and downloads pinned
Hugging Face checkpoints to the normal Hugging Face cache. Later runs reuse both;
no audio is sent to an API. Set `TRANSCRIBE_STATE_DIR` to override the environment
location and `HF_HOME` to override the model cache. Installation needs network
access initially. Model revision IDs are pinned in `speech-transcribe.py`.

```bash
nix-instantiate --parse modules/speech-transcription.nix >/dev/null
```

## Local text-to-speech

`modules/speech-tts.nix` installs `tts` on the desktop:

```bash
tts "Text to speak" --output speech.wav
tts --input script.txt --output speech.wav --language English --speaker ryan
tts --list-speakers
```

Qwen3-TTS 1.7B CustomVoice (Apache-2.0), revision-pinned in `speech-tts.py`, in BF16
on CUDA with the model's preset speakers (no cloning). CUDA is default; `--device cpu`
is explicit. Long input is split at sentence boundaries and joined with short pauses.

It has its own hash-locked environment, separate from the transcription one, under
`${XDG_DATA_HOME:-~/.local/share}/tts/qwen-tts-venv` (`TTS_STATE_DIR` overrides).
First use installs it and downloads the checkpoint into the Hugging Face cache.

```bash
nix-instantiate --parse modules/speech-tts.nix >/dev/null
```

## Wi-Fi backends

Import exactly one Wi-Fi module in the host configuration:

```nix
imports = [ ../../modules/wifi_iwd.nix ]; # iwd
# imports = [ ../../modules/wifi_wpa.nix ]; # wpa_supplicant
```

Both use NetworkManager and import `modules/networkmanager-profiles.nix` for the
same SOPS-managed Wi-Fi and VPN profiles. NetworkManager and its OpenVPN plugin
are enabled in `base.nix`; the secrets are declared in `sops.nix`.

The iwd module loads `pkcs8_key_parser` for eduroam and currently retains the
`eduroam.8021x` template until NetworkManager-only provisioning is tested on
campus. The WPA module selects NetworkManager's `wpa_supplicant` backend and gives
the hardened service read access to the eduroam PEM certificates and private key.
No host-specific settings need changing when switching the import.

## BAR Native

Launch it with `bar-native` or the
**Beyond All Reason (Native)** desktop entry. Both the Lobby and its downloaded
engines run outside FHS, using the host graphics driver without forcing X11 or
PRIME offload. The existing `beyond-all-reason` launcher remains installed.

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
