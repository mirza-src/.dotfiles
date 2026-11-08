{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.gpu.dynamic-mux;
in
# Live internal-panel switching between iGPU and dGPU ("Ultimate" without a
# reboot) on the G14 (GA403).
#
# The panel sits behind a PI3WVR13612 eDP 2:1 mux. The NVIDIA SSDT ("OptRf2")
# exposes the MXM display-mux methods on the dGPU's panel device
# \_SB.PCI0.GPP9.PEGP.LCD0:
#   MXDS(0x01) -> EC.DMUS = 0 (panel -> iGPU), MXDS(0x11) -> EC.DMUS = 1 (dGPU)
#   MXDS(0x00) reads EC.MOLR, which does NOT track the mux position.
#   MXDM writes the boot-time mux mode via SMI (= asus-armoury gpu_mux_mode);
#   never used here.
#
# Pieces:
#   - patched nvidia-modeset (patches/nvidia-open-dynamic-mux.patch, wired in
#     nvidia.nix): /sys/module/nvidia_modeset/parameters/mux runs NVIDIA's own
#     pre/switch/post sequence incl. link training;
#   - cardwired "ultimate" mode (patches/cardwire-ultimate.patch) drives the
#     switch: `cardwire set ultimate|hybrid`, `cardwire mux status`;
#   - patched wlroots + mango move the compositor's render GPU with the panel.
{
  # Our cardwire patch adds the "ultimate" mode; let the module accept it as
  # the on-AC mode (enum declarations of the same option are merged).
  options.services.cardwired.settings = mkOption {
    type = types.submodule {
      options.battery_auto_switch_mode = mkOption {
        type = types.enum [ "ultimate" ];
      };
    };
  };

  options.modules.gpu.dynamic-mux = {
    enable = mkEnableOption "live internal-panel mux switching (cardwire Ultimate mode)";
    panelAcpiId = mkOption {
      type = types.str;
      default = "0x8000A450";
      description = "ACPI _DOD/_ADR id of the panel device under the dGPU (\\_SB.PCI0.GPP9.PEGP.LCD0).";
    };
  };

  config = mkIf cfg.enable {
    # Let the compositor move its render GPU along with the panel: wlroots
    # re-picks the primary DRM device on hotplug (the GPU driving the internal
    # panel wins) and mango rebuilds its renderer on it. The patched wlroots is
    # only handed to scenefx + mango, so nothing else gets rebuilt.
    #
    # mango is built from the mangowm flake input (the pinned nightly the
    # patch is made against) with the scenefx revision that flake pins, not
    # nixpkgs' older `mango`/`scenefx` packages, which `prev` would give here.
    nixpkgs.overlays = [
      (
        final: prev:
        let
          wlroots = prev.wlroots_0_20.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ../../../patches/wlroots-dynamic-primary.patch ];
          });
          scenefx = (prev.scenefx.override { wlroots_0_20 = wlroots; }).overrideAttrs {
            version = "git-${inputs.mangowm.inputs.scenefx.shortRev or "dirty"}";
            src = inputs.mangowm.inputs.scenefx;
          };
        in
        {
          mango =
            (final.callPackage "${inputs.mangowm}/nix" {
              wlroots_0_20 = wlroots;
              inherit scenefx;
            }).overrideAttrs
              (old: {
                patches = (old.patches or [ ]) ++ [ ../../../patches/mango-renderer-migration.patch ];
              });
          # Live-mux "ultimate" mode in cardwired (patch is against v0.12.3).
          cardwire = prev.cardwire.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ../../../patches/cardwire-ultimate.patch ];
          });
        }
      )
    ];

    # cardwired only runs while a graphical session is up.
    #
    # Its blocking modes (Integrated/Smart, also battery auto-switch) stop
    # processes from *opening* the dGPU. A compositor that starts while the
    # dGPU is blocked never gets it: NVIDIA's EGL does not re-scan devices
    # inside a running process (verified), so the session can't use the dGPU
    # (no Ultimate, and adding it at runtime froze mango). Starting cardwired
    # after the compositor lets it open both GPUs first; already open handles
    # keep working under the block, and an idle handle doesn't keep the dGPU
    # out of D3cold. Stopping it with the session lifts the block again before
    # the next login.
    systemd.services.cardwired.wantedBy = mkForce [ ];
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "cardwired.service" &&
            subject.isInGroup("wheel")) {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop" || verb == "restart")
            return polkit.Result.YES;
        }
      });
    '';
    systemd.user.services.cardwire-session = {
      description = "Run cardwired for this graphical session";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Give the compositor a moment to open both GPUs.
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        ExecStart = [
          "${pkgs.systemd}/bin/systemctl start cardwired.service"
          # A persisted "ultimate" starts as pending; apply it now. Exits
          # non-zero when nothing is pending, that's fine.
          "-${pkgs.cardwire}/bin/cardwire mux apply"
        ];
        ExecStop = "${pkgs.systemd}/bin/systemctl stop cardwired.service";
      };
    };
    # The mango flake module defaults to its own build; use the patched one.
    programs.mango.package = pkgs.mango;
    environment.sessionVariables.WLR_DRM_DYNAMIC_PRIMARY = "1";
    # Show wlroots' primary-GPU switch messages in the journal (mango's own
    # default is errors only; this override comes from our mango patch).
    # TODO: drop once live switching has proven stable.
    environment.sessionVariables.MANGO_LOG_LEVEL = "info";

    # cardwired's last-resort revert (driver wedged) writes MXDS 0x1 to
    # /proc/acpi/call; its sandbox can't load modules, so load it at boot.
    boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];
    boot.kernelModules = [ "acpi_call" ];
    # Read by the patched nvidia-modeset at load time to set up the mux.
    boot.extraModprobeConfig = ''
      options nvidia_modeset mux_acpi_id=${cfg.panelAcpiId}
    '';

    # Forcing a connector's status via sysfs only emits a hotplug uevent when
    # the driver polls connectors (nvidia-drm does, amdgpu doesn't). cardwired
    # writes a synthetic "change ... MUXHOTPLUG=1" uevent on the card; turn it
    # into a regular DRM hotplug so every compositor rescans its outputs.
    services.udev.extraRules = ''
      ACTION=="change", SUBSYSTEM=="drm", ENV{SYNTH_ARG_MUXHOTPLUG}=="1", ENV{HOTPLUG}="1"
    '';
  };
}
