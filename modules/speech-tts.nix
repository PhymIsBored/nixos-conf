{ pkgs, ... }:
let
  ttsLauncher = pkgs.writeShellScript "qwen-tts-launch" ''
    set -euo pipefail
    base="''${TTS_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/tts}"
    mkdir -p "$base"
    exec 9>"$base/setup.lock"
    ${pkgs.util-linux}/bin/flock 9
    venv="$base/qwen-tts-venv"
    lock=${./speech-tts-requirements.lock}
    if [ ! -f "$base/requirements-path" ] || [ "$(< "$base/requirements-path")" != "$lock" ]; then
      if [ ! -x "$venv/bin/python" ]; then
        ${pkgs.uv}/bin/uv venv --python /usr/bin/python3.12 "$venv"
      fi
      ${pkgs.uv}/bin/uv pip sync --python "$venv/bin/python" --require-hashes "$lock"
      printf '%s\n' "$lock" > "$base/requirements-path"
    fi
    ${pkgs.util-linux}/bin/flock -u 9
    exec "$venv/bin/python" ${./speech-tts.py} "$@"
  '';
  ttsRuntime = pkgs.buildFHSEnv {
    name = "qwen-tts";
    targetPkgs = p: [
      p.python312
      p.uv
      p.stdenv.cc.cc.lib
      p.zlib
      p.libsndfile
      p.sox
      p.cacert
    ];
    runScript = ttsLauncher;
    profile = ''
      export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      export UV_PYTHON_DOWNLOADS=never
      export PYTHONDONTWRITEBYTECODE=1
    '';
  };
  tts = pkgs.writeShellApplication {
    name = "tts";
    text = ''
      exec ${ttsRuntime}/bin/qwen-tts "$@"
    '';
  };
in
{
  environment.systemPackages = [ tts ];
}
