{ pkgs, ... }:
let
  sherpa = pkgs.python3.withPackages (ps: [ ps.sherpa-onnx ]);

  mkModel = name: url: hash:
    pkgs.fetchurl {
      inherit url hash;
      name = "${name}.tar.bz2";
    };

  parakeetTar = mkModel "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2"
    "sha256-FJXpG1nX/FPdypHzQxdY7Jn4+iU/2w4ehRvg9ysUsPk=";

  qwen3Tar = mkModel "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25"
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2"
    "sha256-OT+KFOL1+5Z0aqqzQpl6QGQQAfvVv5WSoICoMpF47pY=";

  parakeetModel = pkgs.runCommand "parakeet-tdt-0.6b-v3-int8" { } ''
    mkdir -p $out && tar -xjf ${parakeetTar} -C $out --strip-components=1
  '';

  qwen3Model = pkgs.runCommand "qwen3-asr-0.6b-int8" { } ''
    mkdir -p $out && tar -xjf ${qwen3Tar} -C $out --strip-components=1
  '';

  transcribe = pkgs.writeShellApplication {
    name = "transcribe";
    runtimeInputs = [ sherpa pkgs.ffmpeg ];
    text = ''
      usage() {
        echo "usage: transcribe <accuracy|speed> <audio-file>" >&2
        exit 2
      }
      [ $# -eq 2 ] || usage
      mode=$1
      input=$2
      tmp=$(mktemp --suffix=.wav)
      trap 'rm -f "$tmp"' EXIT
      ffmpeg -v error -y -i "$input" -ar 16000 -ac 1 "$tmp"
      case "$mode" in
        speed)
          exec ${sherpa}/bin/python3 ${./speech-transcribe.py} parakeet ${parakeetModel} "$tmp"
          ;;
        accuracy)
          exec ${sherpa}/bin/python3 ${./speech-transcribe.py} qwen3 ${qwen3Model} "$tmp"
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ transcribe ];
}
