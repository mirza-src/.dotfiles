{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.modules.asus;
in
{
  options.modules.asus = {
    enable = mkEnableOption "ASUS Configuration Options";
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
      #
      # Not the -lto variant for now: nix-cachyos-kernel builds LTO kernels
      # without BTF until nixpkgs has pahole >= 1.33 (its commit 3084b743b4),
      # and cardwired's eBPF needs /sys/kernel/btf/vmlinux. Switch back to
      # linuxPackages-cachyos-latest-lto-zen4 once that lands.
      boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4.extend pkgs.kernelModules;

      services.asusd.enable = true;
    })
  ];
}
