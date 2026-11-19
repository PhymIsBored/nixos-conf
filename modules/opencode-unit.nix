{ pkgs, ... }:

{
  systemd.user.services."opencode" = {
    description = "OpenCode server";

    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
    };

    serviceConfig = {
      ExecStart = "${pkgs.opencode}/bin/opencode serve --service --hostname 127.0.0.1 --port 4096";
      Restart = "on-failure";
      RestartSec = 5;
    };

    wantedBy = [ "graphical-session.target" ];
  };
}
