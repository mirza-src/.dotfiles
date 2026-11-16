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

      # Let the input group set Fn-lock without sudo (fn_lock comes from
      # hid-asus-fnlock and exists once the driver has bound).
      services.udev.extraRules = ''
        ACTION=="bind", SUBSYSTEM=="hid", DRIVER=="asus", TEST=="fn_lock", RUN+="${pkgs.coreutils}/bin/chgrp input /sys%p/fn_lock", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/fn_lock"
      '';

      # After a Windows boot where G-Helper set Fn-lock, the state the driver
      # applies at probe doesn't stick. Re-send the driver's state once the
      # system is up so fnlock_default wins.
      systemd.services.fnlock-reapply = {
        description = "Re-apply keyboard Fn-lock state";
        wantedBy = [ "multi-user.target" ];
        after = [
          "systemd-udev-settle.service"
          "asusd.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${lib.getExe pkgs.fnlock} reapply";
        };
      };

      # fnlock [on|off|toggle|status|reapply], for shortcuts and the DMS plugin.
      environment.systemPackages = [ pkgs.fnlock ];
    })
  ];
}
