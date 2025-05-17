{ pkgs, ... }: {
  boot.kernelPackages = pkgs.linuxPackages_zen;

  environment.systemPackages = [
    # For debugging and troubleshooting Secure Boot.
    pkgs.sbctl
  ];

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    settings = {
      timeout = 0;
      console-mode = "2";
      configuration-limit = 16;
      reboot-for-bitlocker = true;
    };
  };

  boot.loader.timeout = 0;
  boot.loader.systemd-boot = {
    enable = false;
    consoleMode = "2";
    configurationLimit = 16;
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;
  boot.kernelParams = ["quiet" "splash" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" "boot.shell_on_fail"];
  boot.initrd.verbose = false;
}
