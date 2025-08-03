{ pkgs, config, ... }:
{
  imports = [
    ./programs.nix
    ./users.nix

    ./hardware-configuration.nix
  ];

  services.printing.enable = true;
  services.fwupd.enable = true;
  networking.networkmanager.enable = true;
  modules.shell.enable = true;
  modules.nix.enable = true;
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
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --xsessions ${config.services.displayManager.sessionData.desktops}/share/xsessions --remember --remember-user-session";
      };
    };
  };

  modules.gnome.enable = true;
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
}
