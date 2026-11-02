{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  asar,
  nodejs,
  callPackage,
  glib,
  nspr,
  nss,
  dbus,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cups,
  cairo,
  gtk3,
  pango,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxkbcommon,
  libgbm,
  expat,
  systemd,
  alsa-lib,
  libglvnd,
  libdrm,
  libpulseaudio,
  libsecret,
  gsettings-desktop-schemas,
  _7zz,
}:
let
  pname = "beyond-all-reason-native";
  version = "1.2988.0";
  src = fetchurl {
    url = "https://github.com/beyond-all-reason/BYAR-Chobby/releases/download/v${version}/Beyond-All-Reason-${version}.AppImage";
    hash = "sha256-ZJW5BdxxqyrM2TJTO0SBp4BXt3ILyi77EZx73X8hqJE=";
  };
  contents = appimageTools.extract { inherit pname version src; };
  runtime = callPackage ../bar-native/runtime.nix { };
in
stdenvNoCC.mkDerivation {
  inherit pname version;
  src = contents;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
    asar
    nodejs
  ];
  buildInputs = [
    glib
    nspr
    nss
    dbus
    atk
    at-spi2-atk
    at-spi2-core
    cups
    cairo
    gtk3
    pango
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxkbcommon
    libgbm
    expat
    systemd
    alsa-lib
    libglvnd
    libdrm
    libpulseaudio
    libsecret
    gsettings-desktop-schemas
    stdenv.cc.cc.lib
  ];
  runtimeDependencies = [
    # Electron loads libudev with dlopen, so autoPatchelf cannot infer it.
    (lib.getLib systemd)
    libglvnd
    libpulseaudio
    libsecret
  ];

  dontWrapGApps = true;
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p "$TMPDIR/appimage"
    cp -r ${contents}/. "$TMPDIR/appimage/"
    chmod -R u+w "$TMPDIR/appimage"
    cd "$TMPDIR/appimage"

    # The AppImage has a dangling build-time python symlink in its unpacked
    # ASAR files. Give ASAR a readable target while unpacking the app bundle.
    ln -sfn ${nodejs}/bin/node \
      resources/app.asar.unpacked/node_modules/register-scheme/build/node_gyp_bins/python3
    asar extract resources/app.asar app

    cp ${./native-spawn.cjs} app/src/nix-child-process.cjs
    substituteInPlace app/src/nix-child-process.cjs \
      --replace-fail '@runtime@' '${runtime}/bin/bar-native-runtime'
    node - <<'NODE'
    const fs = require('node:fs');
    const file = 'app/src/engine_launcher.js';
    const original = fs.readFileSync(file, 'utf8');
    const target = "const { spawn } = require('child_process');";
    if (original.split(target).length !== 2) {
      throw new Error('Expected one child_process spawn import in the BAR engine launcher');
    }
    fs.writeFileSync(file, original.replace(target, "const { spawn } = require('./nix-child-process.cjs');"));
    NODE

    # Use Nix's native 7-Zip rather than the AppImage's bundled executable.
    rm -rf app/node_modules/7zip-bin/linux app/node_modules/7zip-bin/mac
    mkdir -p app/node_modules/7zip-bin/linux/x64
    makeWrapper ${_7zz}/bin/7zz app/node_modules/7zip-bin/linux/x64/7za
    rm -rf app/node_modules/register-scheme/build/node_gyp_bins
    rm -rf resources/app.asar.unpacked
    asar pack app resources/app.asar \
      --unpack '{**/7zip-bin/**,**/*.node}'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/beyond-all-reason $out/bin
    cp -r "$TMPDIR/appimage/locales" "$TMPDIR/appimage/resources" $out/lib/beyond-all-reason/
    cp "$TMPDIR/appimage"/beyond-all-reason \
      "$TMPDIR/appimage"/chrome_crashpad_handler \
      "$TMPDIR/appimage"/chrome-sandbox \
      "$TMPDIR/appimage"/*.pak \
      "$TMPDIR/appimage"/*.bin \
      "$TMPDIR/appimage"/*.dat \
      "$TMPDIR/appimage"/*.json \
      "$TMPDIR/appimage"/*.so* \
      "$TMPDIR/appimage"/LICENSE.electron.txt \
      "$TMPDIR/appimage"/LICENSES.chromium.html \
      $out/lib/beyond-all-reason/
    cp -r "$TMPDIR/appimage/bin" $out/lib/beyond-all-reason/

    install -Dm644 "$TMPDIR/appimage/beyond-all-reason.png" \
      $out/share/icons/hicolor/256x256/apps/beyond-all-reason.png
    install -Dm644 "$TMPDIR/appimage/beyond-all-reason.desktop" \
      $out/share/applications/beyond-all-reason.desktop
    substituteInPlace $out/share/applications/beyond-all-reason.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=beyond-all-reason %U'
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/lib/beyond-all-reason/beyond-all-reason $out/bin/beyond-all-reason \
      "''${gappsWrapperArgs[@]}" \
      --set SDL_VIDEODRIVER x11 \
      --set __NV_PRIME_RENDER_OFFLOAD 1 \
      --set __GLX_VENDOR_LIBRARY_NAME nvidia \
      --add-flags "--no-sandbox --ozone-platform=x11" \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:${lib.makeLibraryPath [ libglvnd ]}
  '';

  passthru = { inherit runtime; };
  meta = {
    description = "Beyond All Reason launcher with a native, non-FHS engine runtime";
    homepage = "https://www.beyondallreason.info/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "beyond-all-reason";
  };
}
