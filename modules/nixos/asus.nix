{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.asus;
in
{
  imports = [
    inputs.asus-dialpad-driver.nixosModules.default
  ];

  options.modules.asus = {
    enable = mkEnableOption "Enable ASUS Configuration Options";

    ghelper = {
      enable = lib.mkEnableOption "G-Helper Linux" // {
        default = true;
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.ghelper;
        description = "Package providing the ghelper binary and integration files.";
      };

      enableGpuBootService =
        lib.mkEnableOption "Enable the G-Helper GPU boot helper systemd service."
        // {
          default = true;
        };
    };
  };

  config =
    (mkIf cfg.enable {
      nixpkgs.overlays = [
        inputs.cachyos-kernel.overlays.default
      ];

      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4;
      boot.extraModulePackages = with config.boot.kernelPackages; [
        ryzen-smu
      ];
      boot.kernelModules = [ "ryzen_smu" ];
      boot.extraModprobeConfig = ''
        options asus_wmi fnlock_default=Y
      '';
      hardware.enableAllFirmware = true;
      hardware.enableAllHardware = true;
      environment.systemPackages = with pkgs; [
        linux-firmware
      ];
      services.asusd.enable = true;
      programs.rog-control-center.enable = true;
      services.asus-dialpad-driver.enable = false;
    })
    // (lib.mkIf cfg.ghelper.enable {
      environment.systemPackages = [ cfg.ghelper.package ];
      services.udev.packages = [ cfg.ghelper.package ];
      systemd.packages = lib.mkIf cfg.ghelper.enableGpuBootService [ cfg.ghelper.package ];
    });
}
