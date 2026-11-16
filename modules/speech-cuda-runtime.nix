{ pkgs }:
let
  cuda = pkgs.cudaPackages_12;
in
pkgs.stdenv.mkDerivation {
  pname = "sherpa-onnx-cuda-bin";
  version = "1.13.8";
  src = pkgs.fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v1.13.8/sherpa-onnx-v1.13.8-cuda-12.x-cudnn-9.x-onnxruntime1.28.2-linux-x64-gpu.tar.bz2";
    hash = "sha256-ITKvGujITIT4asCR5DEYOSh4UdK/XmYDMuvOOJih4LI=";
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.alsa-lib cuda.libcublas cuda.libcurand cuda.cuda_cudart cuda.cudnn ];
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin $out/lib
    cp lib/*.so $out/lib/
    rm $out/lib/libonnxruntime_providers_tensorrt.so
    cp bin/sherpa-onnx-offline $out/bin/
    wrapProgram $out/bin/sherpa-onnx-offline \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ cuda.cudnn cuda.libcublas cuda.libcurand cuda.cuda_cudart ]}:/run/opengl-driver/lib:$out/lib"
  '';
}
