{ pkgs, ... }:

{
  systemd.user.services."opencode" = {
    description = "OpenCode server";
    after = [ "nss-lookup.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.opencode}/bin/opencode serve --service --host ::1 --port 4096";
      Restart = "on-failure";
      RestartSec = 2;
    };

    wantedBy = [ "graphical-session.target" ];
  };
}
