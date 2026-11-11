{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  cfg = config.modules.gpu.nvidia-prime;
in
{
  imports = [
    ./nvidia.nix
  ];

  options.modules.gpu.nvidia-prime = {
    enable = mkEnableOption "Nvidia Prime Hybrid GPU Offload";
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

      modules.gpu.nvidia.enable = true;
      hardware.nvidia = {
        prime = {
          offload = {
            enable = true;
            enableOffloadCmd = config.hardware.nvidia.prime.offload.enable;
          };
          # Make sure to use the correct Bus ID values for your system!
          intelBusId = mkIf (cfg.intelBusId != null) cfg.intelBusId;
          amdgpuBusId = mkIf (cfg.amdBusId != null) cfg.amdBusId;
          nvidiaBusId = mkIf (cfg.nvidiaBusId != null) cfg.nvidiaBusId;
        };
      };
    })

    (mkIf (cfg.enable && config.services.desktopManager.gnome.enable) {
      environment.systemPackages =
        with pkgs;
        (with gnomeExtensions; [
          cardwire-gpu-toggle
        ]);
      programs.dconf = {
        enable = true;
        profiles.user.databases = [
          {
            settings = {
              "org/gnome/shell" = {
                enabled-extensions = with pkgs.gnomeExtensions; [
                  cardwire-gpu-toggle.extensionUuid
                ];
              };
            };
          }
        ];
      };
    })
  ];
}
