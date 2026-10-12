{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.faf;

  fafSteam = pkgs.steam.override {
    extraPkgs =
      p: with p; [
        git
        curl
        jq
        bubblewrap
        libxtst
        gtk3
      ];
  };

  installer = pkgs.writeShellApplication {
    name = "faf-install";

    text = ''
      dir="$HOME"/${lib.escapeShellArg cfg.directory}
      mkdir -p "$dir"
      cd "$dir"

      exec ${fafSteam.run}/bin/steam-run bash -c '
        set -e

        if [[ ! -d .git ]]; then
          git clone https://github.com/FAForever/faf-linux.git .
        fi

        if [[ ! -f ./setup.sh ]]; then
          echo "Missing setup.sh; check the installation directory." >&2
          exit 1
        fi

        ./setup.sh
      '
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "faf";
    text = ''
      dir="$HOME"/${lib.escapeShellArg cfg.directory}

      if [[ ! -f "$dir/run" ]]; then
        echo "FAF is not installed in $dir. Run the installation steps first." >&2
        exit 1
      fi

      cd "$dir"
      exec ${fafSteam.run}/bin/steam-run ./run "$@"
    '';
  };

  shell = pkgs.writeShellApplication {
    name = "faf-shell";
    text = ''
      dir="$HOME"/${lib.escapeShellArg cfg.directory}
      mkdir -p "$dir"
      cd "$dir"
      exec ${fafSteam.run}/bin/steam-run bash "$@"
    '';
  };

  desktop = pkgs.makeDesktopItem {
    name = "faf";
    desktopName = "Forged Alliance Forever";
    comment = "Launch the FAF client";
    exec = "${launcher}/bin/faf";
    icon = "applications-games";
    categories = [ "Game" ];
    terminal = false;
  };
in
{
  options.programs.faf = {
    enable = lib.mkEnableOption "Forged Alliance Forever via faf-linux";

    directory = lib.mkOption {
      type = lib.types.str;
      default = "faf-linux";
      description = ''
        Installation directory relative to the user's home directory.
        Keep it outside Steam-managed directories.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    environment.systemPackages = [
      installer
      launcher
      shell
      desktop
    ];
  };
}
