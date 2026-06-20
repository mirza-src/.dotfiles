{ lib, config, ... }:
{
  programs.dank-material-shell.greeter.configHome = "/home/mirza";
  programs.dank-material-shell.greeter.compositor.customConfig =
    lib.mkIf (config.programs.dank-material-shell.greeter.compositor.name == "niri")
      ''
        hotkey-overlay {
          skip-at-startup
        }

        environment {
          DMS_RUN_GREETER "1"
        }

        debug {
          keep-max-bpc-unchanged

          // Use integrated GPU /dev/dri/by-path/pci-0000:65:00.0-render
          render-drm-device "/dev/dri/renderD128"
          // ignore-drm-device "/dev/dri/renderD129"
        }

        gestures {
          hot-corners {
            off
          }
        }

        layout {
          background-color "#000000"
        }

        input {
          touchpad {
            tap
            natural-scroll
          }
        }
      '';

  users.users = {
    mirza = {
      isNormalUser = true;
      description = "Mirza Esaaf Shuja";
      autoSubUidGidRange = true;
      initialPassword = "password"; # Change this on first login
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "podman"
        "input"
        "audio"
        "video"
        "disk"
        "incus-admin"
        "libvirtd"
      ];
    };

    maira = {
      isNormalUser = true;
      description = "Maira Tariq";
      autoSubUidGidRange = true;
      initialPassword = "password"; # Change this on first login
      extraGroups = [
        "networkmanager"
        "docker"
        "podman"
        "input"
        "audio"
        "video"
      ];
    };
  };
}
