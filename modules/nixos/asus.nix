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
  };

  config = mkIf cfg.enable {
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
  };
}
