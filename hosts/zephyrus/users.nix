{ ... }:
{
  programs.dank-material-shell.greeter.configHome = "/home/mirza";
  programs.dank-material-shell.greeter.compositor.customConfig = ''
    hotkey-overlay {
      skip-at-startup
    }

    environment {
      DMS_RUN_GREETER "1"
    }

    debug {
      keep-max-bpc-unchanged
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
        "libvirt"
      ];
    };
  };
}
