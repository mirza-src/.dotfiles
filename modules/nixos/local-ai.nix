{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    elem
    head
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.local-ai;
in
{
  options.modules.local-ai = {
    enable = mkEnableOption "Local AI stack featuring Ollama, Open WebUI, and OpenCode";

    autostart = mkEnableOption "starting the local AI stack automatically at boot";

    gpuAcceleration = mkOption {
      type = types.enum [
        "cuda"
        "rocm"
        "vulkan"
        "cpu"
      ];
      default = "cuda";
      description = "Hardware acceleration engine to use for inference pipelines.";
    };

    webuiPort = mkOption {
      type = types.port;
      default = 8080;
      description = "The port network bind for the Open WebUI panel dashboard.";
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [
        "qwen2.5:0.5b"
        # Dense
        "qwen3.5:9b"
        "hf.co/unsloth/gemma-4-12B-it-qat-GGUF:UD-Q4_K_XL"
        # MoE (larger than VRAM, Ollama splits them across GPU and CPU)
        "hf.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL"
        "hf.co/unsloth/qwen3.6-35B-A3B-GGUF:UD-IQ4_XS"
        # Needs llama.cpp's llama-diffusion-cli; Ollama's llama-server can't run it yet.
        # "hf.co/unsloth/diffusiongemma-26B-A4B-it-GGUF:Q4_K_M"
      ];
      description = "List of model parameters for Ollama to fetch on system rebuild activation.";
    };

    taskModel = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Model from `models` Open WebUI uses for titles, tags and follow-ups. Defaults to the first model.";
    };
  };

  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.models != [ ];
        message = "modules.local-ai.models must contain at least one model.";
      }
      {
        assertion = cfg.taskModel == null || elem cfg.taskModel cfg.models;
        message = "modules.local-ai.taskModel must be one of modules.local-ai.models.";
      }
      {
        assertion = cfg.gpuAcceleration != "cuda" || config.modules.gpu.nvidia.enable;
        message = "modules.local-ai.gpuAcceleration = \"cuda\" needs modules.gpu.nvidia.enable.";
      }
      {
        assertion = cfg.gpuAcceleration != "rocm" || config.modules.gpu.amd.enable;
        message = "modules.local-ai.gpuAcceleration = \"rocm\" needs modules.gpu.amd.enable.";
      }
    ];

    # Drivers come from the GPU modules (modules.gpu.*); this only runs the
    # inference stack on top of them.
    services.ollama = {
      enable = true;
      package = pkgs.${"ollama-${cfg.gpuAcceleration}"};
      loadModels = cfg.models;
      environmentVariables = {
        # Default 4096 truncates longer chats (prompts were hitting 4095 tokens).
        OLLAMA_CONTEXT_LENGTH = "16384";
        # Keep the chat and task models loaded side by side, and let one model
        # serve two requests at once so background tasks don't block the chat.
        OLLAMA_MAX_LOADED_MODELS = "2";
        OLLAMA_NUM_PARALLEL = "2";
      };
    };
    systemd.services.ollama.wantedBy = lib.mkForce [ ];
    systemd.services.ollama.partOf = [ "local-ai.target" ];
    systemd.services.ollama-model-loader.wantedBy = lib.mkForce [ "ollama.service" ];

    services.open-webui = {
      enable = true;
      port = cfg.webuiPort;
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        WEBUI_AUTH = "False";
        TASK_MODEL = if cfg.taskModel != null then cfg.taskModel else head cfg.models;
      };
    };
    systemd.services.open-webui.wantedBy = lib.mkForce [ ];
    systemd.services.open-webui.bindsTo = [ "ollama.service" ];
    systemd.services.open-webui.partOf = [ "local-ai.target" ];

    systemd.targets.local-ai = {
      description = "Local AI stack";
      wants = [
        "ollama.service"
        "open-webui.service"
      ];
      after = [
        "ollama.service"
        "open-webui.service"
      ];
      wantedBy = mkIf cfg.autostart [ "multi-user.target" ];
    };

    environment.systemPackages = with pkgs; [
      git
      lmstudio
      opencode
    ];

    environment.etc."opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://localhost:11434/v1";
          };
        };
      };
    };
  };
}
