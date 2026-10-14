{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "bar" ''
      exec ${pkgs.coreutils}/bin/env \
        SDL_VIDEODRIVER=x11 \
        __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        ${pkgs.beyond-all-reason}/bin/beyond-all-reason \
        --ozone-platform=x11 "$@"
    '')
  ];
}
