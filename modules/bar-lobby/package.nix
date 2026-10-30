{
  lib,
  fetchurl,
  appimageTools,
}:

let
  pname = "bar-lobby";
  version = "0.17.1";

  src = fetchurl {
    url = "https://github.com/beyond-all-reason/bar-lobby/releases/download/v${version}/BeyondAllReason-${version}.AppImage";
    hash = "sha256-3HMEUpFQYiDXEDBXVYeTToNClw9vKWFCWlKGbrxbdAg=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The downloaded engine and pr-downloader run inside this FHS environment.
  extraPkgs =
    pkgs: with pkgs; [
      openal
      boost
    ];

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/bar-lobby.desktop \
      $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail "Exec=AppRun" "Exec=${pname}" \
      --replace-fail "Name=BeyondAllReason" "Name=Beyond All Reason (BAR Lobby)"
    install -Dm644 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/bar-lobby.png \
      $out/share/icons/hicolor/512x512/apps/${pname}.png
  '';

  meta = {
    description = "BAR Lobby client for Beyond All Reason";
    longDescription = ''
      Wraps the official release AppImage in a Nix FHS environment. The
      engine, maps and game content are downloaded to the user's data
      directory at runtime. Update the lobby through Nix by changing both
      version and the source hash; the in-app updater cannot update the
      read-only store installation.
    '';
    homepage = "https://github.com/beyond-all-reason/bar-lobby";
    changelog = "https://github.com/beyond-all-reason/bar-lobby/releases/tag/v${version}";
    # The AppImage bundles non-free assets in addition to the MIT lobby code.
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
