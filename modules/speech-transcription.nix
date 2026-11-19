{ pkgs, ... }:
let
  cudaRuntime = import ./speech-cuda-runtime.nix { inherit pkgs; };
  parakeetTar = pkgs.fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2";
    hash = "sha256-FJXpG1nX/FPdypHzQxdY7Jn4+iU/2w4ehRvg9ysUsPk=";
  };
  parakeetModel = pkgs.runCommand "parakeet-tdt-0.6b-v3-int8" { } ''
    mkdir -p $out
    tar -xjf ${parakeetTar} -C $out --strip-components=1
  '';
  qwenLauncher = pkgs.writeShellScript "qwen-transcription-launch" ''
    set -euo pipefail
    base="''${TRANSCRIBE_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/transcription}"
    mkdir -p "$base"
    exec 9>"$base/setup.lock"
    ${pkgs.util-linux}/bin/flock 9
    venv="$base/qwen-venv"
    lock=${./speech-requirements.lock}
    if [ ! -f "$base/requirements-path" ] || [ "$(< "$base/requirements-path")" != "$lock" ]; then
      if [ ! -x "$venv/bin/python" ]; then
        ${pkgs.uv}/bin/uv venv --python /usr/bin/python3.12 "$venv"
      fi
      ${pkgs.uv}/bin/uv pip sync --python "$venv/bin/python" --require-hashes "$lock"
      printf '%s\n' "$lock" > "$base/requirements-path"
    fi
    ${pkgs.util-linux}/bin/flock -u 9
    exec "$venv/bin/python" ${./speech-transcribe.py} "$@"
  '';
  qwenRuntime = pkgs.buildFHSEnv {
    name = "qwen-transcription";
    targetPkgs = p: [
      p.python312
      p.uv
      p.stdenv.cc.cc.lib
      p.zlib
      p.libsndfile
      p.sox
      p.ffmpeg
      p.cacert
    ];
    runScript = qwenLauncher;
    profile = ''
      export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      export UV_PYTHON_DOWNLOADS=never
      export PYTHONDONTWRITEBYTECODE=1
    '';
  };
  transcribe = pkgs.writeShellApplication {
    name = "transcribe";
    runtimeInputs = [
      pkgs.python3
      pkgs.ffmpeg
    ];
    text = ''
      case "''${1:-}" in
        accuracy)
          exec ${qwenRuntime}/bin/qwen-transcription "$@"
          ;;
        *)
          export PARAKEET_MODEL=${parakeetModel}
          export SHERPA_CUDA_BIN=${cudaRuntime}/bin/sherpa-onnx-offline
          exec ${pkgs.python3}/bin/python3 ${./speech-transcribe.py} "$@"
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ transcribe ];
}
