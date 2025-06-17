{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.nvidia-prime;
in
{
  options.modules.nvidia-prime = {
    enable = mkEnableOption "Enable Nvidia Prime Hybrid GPU Offload";
    intelBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:0:0:0";
    };
    amdBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:0:1:0";
    };
    nvidiaBusId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "PCI:0:2:0";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.nvidiaBusId != null;
          message = "You must specify a nvidiaBusId.";
        }
        {
          assertion = cfg.intelBusId != null || cfg.amdBusId != null;
          message = "You must specify at least one of intelBusId or amdBusId.";
        }
        {
          assertion = cfg.intelBusId == null || cfg.amdBusId == null;
          message = "You cannot specify both intelBusId and amdBusId at the same time.";
        }
      ];

      hardware.nvidia = {
        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
          # Make sure to use the correct Bus ID values for your system!
          intelBusId = mkIf (cfg.intelBusId != null) cfg.intelBusId;
          amdgpuBusId = mkIf (cfg.amdBusId != null) cfg.amdBusId;
          nvidiaBusId = mkIf (cfg.nvidiaBusId != null) cfg.nvidiaBusId;
        };
      };

      services.supergfxd.enable = true;
    })

    (mkIf (cfg.enable && config.services.desktopManager.gnome.enable) {
      environment.systemPackages =
        with pkgs;
        (with gnomeExtensions; [
          gpu-supergfxctl-switch
        ]);
      programs.dconf = {
        enable = true;
        profiles.user.databases = [
          {
            settings = {
              "org/gnome/shell" = {
                enabled-extensions = with pkgs.gnomeExtensions; [
                  gpu-supergfxctl-switch.extensionUuid
                ];
              };
            };
          }
        ];
      };
    })
  ];
}
