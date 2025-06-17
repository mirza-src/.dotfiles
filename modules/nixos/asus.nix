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
    # inputs.chaotic.nixosModules.nyx-overlay
  ];

  options.modules.asus = {
    enable = mkEnableOption "Enable ASUS Configuration Options";
  };

  config = mkIf cfg.enable {
    boot.kernelPackages = mkDefault pkgs.linuxPackages_cachyos; # From Chaotic NixOS
    hardware.enableAllFirmware = true;
    hardware.enableAllHardware = true;
    environment.systemPackages = with pkgs; [
      linux-firmware
    ];
    services.asusd = {
      enable = true;
      enableUserService = true;
    };
    programs.rog-control-center.enable = true;
    services.asus-dialpad-driver.enable = true;
  };
}
