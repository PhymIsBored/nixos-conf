# disko-config.nix
let
  disk = "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
  username = "finn";

  btrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = disk;

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
            extraFormatArgs = [ "--type" "luks2" ];

            content = {
              type = "btrfs";

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
                  mountpoint = "/home/${username}/.Steam";
                  mountOptions = btrfsMountOptions;
                };
              };
            };
          };
        };
      };
    };
  };
}
