{
  pkgs,
  config,
  lib,
  ...
}:
{
  imports = [
    ./programs.nix
    ./users.nix

    ./hardware-configuration.nix
  ];

  environment.etc.crypttab = {
    mode = "0600";
    text = ''
      # <volume-name> <encrypted-device> [key-file] [options]
      decrypted_5566d63a-c313-431f-b1eb-92783a05e978 /dev/disk/by-uuid/5566d63a-c313-431f-b1eb-92783a05e978 /etc/cryptsetup-keys.d/5DF837A3-4E01-4423-8C18-9FA849F945D2.BEK bitlk
    '';
  };

  fileSystems."/media/5566d63a-c313-431f-b1eb-92783a05e978" = {
    device = "/dev/mapper/decrypted_5566d63a-c313-431f-b1eb-92783a05e978";
    fsType = "ntfs3";
    options = [
      "uid=0"
      "gid=100"
      "rw"
      "user"
      "exec"
      "nofail"
      "umask=007"
    ];
  };

  services.printing.enable = true;
  services.fwupd.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openconnect
  ];

  modules.shell.enable = true;
  modules.nix.enable = true;
  services.numtide-rke2 = {
    enable = true;
    settings.write-kubeconfig-mode = "0600";
  };
  systemd.services.numtide-rke2.wantedBy = lib.mkForce [ ];
  modules.k3s.enable = true;

  modules.locale = "en_US.UTF-8";
  services.xserver.xkb.layout = "us";
  time.timeZone = null;
  time.hardwareClockInLocalTime = true;
  services.automatic-timezoned.enable = true;

  modules.audio.enable = true;
  modules.asus.enable = true;
  modules.gpu.enable = true;
  modules.gpu-amd.enable = true;
  modules.gpu-nvidia.enable = true;
  modules.nvidia-prime.enable = true;
  modules.nvidia-prime.amdBusId = "PCI:102:0:0";
  modules.nvidia-prime.nvidiaBusId = "PCI:101:0:0";
  modules.gaming.enable = true;
  modules.power.enable = true;
  services.system76-scheduler.enable = true;
  services.system76-scheduler.useStockConfig = true;

  modules.silent-boot.enable = true;
  modules.secure-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = false;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions --remember --remember-user-session";
      };
    };
  };

  modules.gnome.enable = false;
  programs.hyprland.enable = true;
  services.xserver.desktopManager.kodi.enable = true;
  services.xserver.desktopManager.kodi.package = pkgs.kodi.withPackages (
    kodiPkgs: with kodiPkgs; [
      joystick
      youtube
      netflix
      pdfreader
      steam-library
      steam-launcher
      steam-controller
      bluetooth-manager
    ]
  );

  services.ollama = {
    enable = true;
  };
}
