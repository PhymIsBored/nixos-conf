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
  pname = "bar-native";
  version = "0.17.1";
  src = fetchurl {
    url = "https://github.com/beyond-all-reason/bar-lobby/releases/download/v${version}/BeyondAllReason-${version}.AppImage";
    hash = "sha256-3HMEUpFQYiDXEDBXVYeTToNClw9vKWFCWlKGbrxbdAg=";
  };
  contents = appimageTools.extract {
    inherit pname version src;
  };
  runtime = callPackage ./runtime.nix { };
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
    libglvnd
    libpulseaudio
    libsecret
  ];

  dontWrapGApps = true;
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    asar extract resources/app.asar app
    cp ${./native-spawn.cjs} app/.vite/build/nix-child-process.cjs
    substituteInPlace app/.vite/build/nix-child-process.cjs \
      --replace-fail '@runtime@' '${runtime}/bin/bar-native-runtime'
    # Fail on upstream bundle changes instead of silently losing the adapter.
    node - <<'NODE'
    const fs = require('node:fs');
    const file = 'app/.vite/build/main.cjs';
    const original = fs.readFileSync(file, 'utf8');
    const target = 'require("child_process")';
    if (original.split(target).length !== 3) {
      throw new Error('Expected two child_process imports in the Lobby main bundle');
    }
    fs.writeFileSync(file, original.replaceAll(target, 'require("./nix-child-process.cjs")'));
    NODE
    # Drop foreign-architecture executables and use Nix's native 7-Zip. No
    # downloaded engine or user-owned file needs patching, renaming or watching.
    rm -r app/node_modules/7zip-bin/linux app/node_modules/7zip-bin/mac
    mkdir -p app/node_modules/7zip-bin/linux/x64
    makeWrapper ${_7zz}/bin/7zz app/node_modules/7zip-bin/linux/x64/7za
    rm -r resources/app.asar.unpacked
    asar pack app resources/app.asar --unpack '**/7zip-bin/**'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/bar-native $out/bin
    cp -r locales resources $out/lib/bar-native/
    cp bar-lobby chrome_crashpad_handler chrome-sandbox *.pak *.bin *.dat *.so* \
      LICENSE.electron.txt LICENSES.chromium.html $out/lib/bar-native/
    install -Dm644 bar-lobby.desktop $out/share/applications/bar-native.desktop
    substituteInPlace $out/share/applications/bar-native.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox' 'Exec=bar-native' \
      --replace-fail 'Name=BeyondAllReason' 'Name=Beyond All Reason (Native)' \
      --replace-fail 'Icon=bar-lobby' 'Icon=bar-native'
    install -Dm644 bar-lobby.png $out/share/icons/hicolor/512x512/apps/bar-native.png
    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/lib/bar-native/bar-lobby $out/bin/bar-native \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:${lib.makeLibraryPath [ libglvnd ]}
  '';

  passthru = { inherit runtime; };
  meta = {
    description = "Beyond All Reason Lobby with a native, non-FHS engine runtime";
    homepage = "https://github.com/beyond-all-reason/bar-lobby";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bar-native";
  };
}
