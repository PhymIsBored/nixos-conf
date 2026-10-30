{
  lib,
  writeShellApplication,
  stdenv,
  SDL2,
  openal,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  libxinerama,
  libxrender,
  libxfixes,
  libxxf86vm,
  libglvnd,
  wayland,
  libxkbcommon,
  libgbm,
  cacert,
}:
let
  libraryPath = lib.makeLibraryPath [
    SDL2
    openal
    libx11
    libxcursor
    libxrandr
    libxi
    libxinerama
    libxrender
    libxfixes
    libxxf86vm
    libglvnd
    wayland
    libxkbcommon
    libgbm
    stdenv.cc.cc
  ];
in
writeShellApplication {
  name = "bar-native-runtime";
  text = ''
    if [[ $# -lt 1 || "$1" != /* || ! -f "$1" ]]; then
      echo 'Usage: bar-native-runtime /absolute/path/to/{spring,spring-headless,spring-dedicated,pr-downloader} [arguments...]' >&2
      exit 64
    fi

    binary="$1"
    shift
    case "''${binary##*/}" in
      spring|spring-headless|spring-dedicated)
        engine_dir="''${binary%/*}"
        # Explicit ld.so invocation changes /proc/self/exe, so the engine
        # cannot discover its fonts, base archives and AI via its executable.
        export SPRING_DATADIR="$engine_dir''${SPRING_DATADIR:+:$SPRING_DATADIR}"
        export SPRING_ISOLATED="$engine_dir"
        ;;
      pr-downloader)
        export PRD_SSL_CERT_FILE="''${PRD_SSL_CERT_FILE:-${cacert}/etc/ssl/certs/ca-bundle.crt}"
        ;;
      *)
        echo "bar-native-runtime: unsupported binary: $binary" >&2
        exit 64
        ;;
    esac

    # Never propagate Electron's bundled EGL/GLES libraries to the engine.
    # Use the host driver, not a pinned NVIDIA userspace/kernel combination.
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${libraryPath}"
    exec ${stdenv.cc.bintools.dynamicLinker} \
      --library-path "$LD_LIBRARY_PATH" --argv0 "$binary" "$binary" "$@"
  '';
}
