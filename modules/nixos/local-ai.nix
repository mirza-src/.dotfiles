# NixOS half of modules.local-ai (catalog, llama-swap config and routes in
# ../common/local-ai.nix): llama-swap with a GPU build of llama.cpp and
# PyTorch (ComfyUI), the llama-models service that downloads the models
# ahead of time, and Open WebUI.
#
# ComfyUI's models and custom nodes: /var/lib/llama-swap/comfyui.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.local-ai;

  # nixpkgs built with CUDA, the configuration cache.nixos-cuda.org builds:
  # its llama.cpp and PyTorch come prebuilt from there instead of from a
  # local multi-hour build.
  pkgsCuda = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = config.nixpkgs.config // {
      cudaSupport = true;
    };
  };

  llamaCppFor = {
    cuda = pkgsCuda.llama-cpp;
    rocm = pkgs.llama-cpp.override { rocmSupport = true; };
    vulkan = pkgs.llama-cpp.override { vulkanSupport = true; };
    cpu = pkgs.llama-cpp;
  };
in
{
  options.modules.local-ai = {
    gpuAcceleration = mkOption {
      type = types.enum [
        "cuda"
        "rocm"
        "vulkan"
        "cpu"
      ];
      default = "cuda";
      description = "llama.cpp backend.";
    };
  };

  config = mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.gpuAcceleration != "cuda" || config.modules.gpu.nvidia.enable;
            message = "modules.local-ai.gpuAcceleration = \"cuda\" needs modules.gpu.nvidia.enable.";
          }
        ];

        modules.local-ai = {
          llamaCpp = llamaCppFor.${cfg.gpuAcceleration};
          modelDir = lib.mkDefault "/var/cache/llama-swap/models";
          comfyui = {
            package = lib.mkDefault (if cfg.gpuAcceleration == "cuda" then pkgsCuda.comfyui else pkgs.comfyui);
            dataDir = lib.mkDefault "/var/lib/llama-swap/comfyui";
          };
        };

        # Idle llama-swap holds no model, so it can always run.
        services.llama-swap = {
          enable = true;
          listenAddress = "127.0.0.1"; # reached through the reverse proxy
          inherit (cfg) port settings;
        };

        # The /llm router (see ../common/local-ai.nix).
        services.litellm = {
          enable = true;
          host = "127.0.0.1";
          inherit (cfg.router) port settings;
        };

        # Downloads the catalog's models at boot and after a rebuild that
        # changed it (only what's missing or updated), retrying while offline.
        # Same dynamic user and cache directory as llama-swap, which reads them.
        systemd.services.llama-models = {
          description = "Download the llama-swap models";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true; # so a changed catalog re-runs it on switch
            ExecStart = cfg.pullCommand;
            Restart = "on-failure";
            RestartSec = "10min";
            DynamicUser = true;
            User = "llama-swap";
            CacheDirectory = "llama-swap";
            Nice = 19;
            IOSchedulingClass = "idle";
          };
        };
      }

      (mkIf cfg.webui.enable {
        services.open-webui = {
          enable = true;
          host = "127.0.0.1";
          inherit (cfg.webui) port environment;
        };
      })

      (mkIf cfg.imageGen.enable {
        systemd.services.llama-swap = {
          environment.HOME = "/var/lib/llama-swap";
          serviceConfig = {
            StateDirectory = "llama-swap"; # ComfyUI's dataDir
            # PyTorch generates code at run time.
            MemoryDenyWriteExecute = lib.mkForce false;
          };
        };
      })
    ]
  );
}
