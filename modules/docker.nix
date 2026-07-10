{ config, ... }:
{
  virtualisation.docker.enable = true;
  users.users."finn".extraGroups = [ "docker" ];
}
