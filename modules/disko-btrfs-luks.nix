{ ... }:
let
  username = "finn";

  btrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  # Each host sets `disko.devices.disk.main.device` to its target disk path.
  disko.devices.disk.main = {
    type = "disk";

    content = {
      type = "gpt";

      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";

          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        encrypted = {
          size = "100%";

          content = {
            type = "luks";
            name = "cryptroot";
            extraFormatArgs = [
              "--type"
              "luks2"
            ];
            settings = {
              allowDiscards = true;
              bypassWorkqueues = true;
            };

            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];

              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = btrfsMountOptions;
                };

                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = btrfsMountOptions;
                };

                "@home" = {
                  mountpoint = "/home";
                  mountOptions = btrfsMountOptions;
                };

                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = btrfsMountOptions;
                };

                "@home-snapshots" = {
                  mountpoint = "/home/.snapshots";
                  mountOptions = btrfsMountOptions;
                };

                "@steam" = {
                  mountpoint = "/home/${username}/.local/share/Steam";
                  mountOptions = btrfsMountOptions;
                };
              };
            };
          };
        };
      };
    };
  };

  # Required because sops.age.keyFile lives inside /home/${username}/.config/sops/age/keys.txt
  fileSystems."/home".neededForBoot = true;

  # Ensure user ownership on directories that systemd may create before first login
  # when mounting the @steam subvolume inside /home/${username}.
  systemd.tmpfiles.rules = [
    "d /home/${username} 0700 ${username} users -"
    "d /home/${username}/.local 0755 ${username} users -"
    "d /home/${username}/.local/share 0755 ${username} users -"
    "d /home/${username}/.local/share/Steam 0755 ${username} users -"
  ];
}
