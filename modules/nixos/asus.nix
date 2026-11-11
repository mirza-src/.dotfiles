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
  options.modules.asus = {
    enable = mkEnableOption "Enable ASUS Configuration Options";
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      nixpkgs.overlays = [
        # pinned = built against the flake's own nixpkgs, so it hits cache.lantian.pub
        inputs.cachyos-kernel.overlays.pinned
      ];

      hardware.enableAllFirmware = true;
      hardware.enableAllHardware = true;

      boot.kernelModules = [ "ryzen_smu" ];
      # Y = F1-F12 without Fn, N = hotkeys without Fn (needs hid-asus-fnlock).
      # Fn+Esc switches it at runtime.
      boot.extraModprobeConfig = ''
        options hid_asus fnlock_default=N
      '';
      boot.extraModulePackages = with config.boot.kernelPackages; [
        ryzen-smu
        hid-asus-fnlock
        mt7925-regd-fix # AirDrop (AWDL) broken by 7.3's self-managed regd
      ];
      # + our kernel modules from pkgs-kernel/ (see overlay.nix)
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-zen4.extend pkgs.kernelModules;

      services.asusd.enable = true;
      environment.systemPackages = with pkgs; [
        linux-firmware
      ];
    })
  ];
}
