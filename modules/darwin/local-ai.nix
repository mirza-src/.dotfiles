# macOS half of modules.local-ai (catalog, llama-swap config and routes in
# ../common/local-ai.nix): llama-swap with llama.cpp on Metal and ComfyUI on
# MPS, the router and Open WebUI, as launchd agents of the logged-in user
# (Metal needs the user's GUI session), on localhost behind the reverse
# proxy.
#
# Models: ~/Library/Caches/llama-swap/models, downloaded by the llama-models
# agent at login and after a rebuild that changed the catalog.
# ComfyUI's models and custom nodes: ~/.local/share/comfyui.
# Logs: /tmp/{llama-swap,llama-models,litellm,open-webui}.log.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  cfg = config.modules.local-ai;
  home = "/Users/${config.system.primaryUser}";
  yaml = pkgs.formats.yaml { };
in
{
  options.modules.local-ai.gpuMemoryMB = mkOption {
    type = types.nullOr types.ints.positive;
    # 32 GB Mac: macOS lets the GPU wire only ~2/3 (21 GB) by default, too
    # little for a 18-20 GB model plus its context. 6 GB stays for the OS.
    default = 26624;
    description = "GPU wired memory limit (sysctl iogpu.wired_limit_mb); null keeps macOS's default.";
  };

  config = mkIf cfg.enable {
    modules.local-ai = {
      modelDir = lib.mkDefault "${home}/Library/Caches/llama-swap/models";
      # No spaces: it ends up in a database URL.
      comfyui.dataDir = lib.mkDefault "${home}/.local/share/comfyui";
    };

    # Downloads only what's missing or updated; a failure (offline) is
    # retried every 10 minutes.
    launchd.user.agents.llama-models.serviceConfig = {
      ProgramArguments = [ "${cfg.pullCommand}" ];
      RunAtLoad = true;
      KeepAlive.SuccessfulExit = false;
      ThrottleInterval = 600;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/tmp/llama-models.log";
      StandardErrorPath = "/tmp/llama-models.log";
    };

    # The /llm router (see ../common/local-ai.nix), like NixOS'
    # services.litellm: its web UI and tokenizer cache in a writable place.
    launchd.user.agents.litellm.serviceConfig = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          mkdir -p "$LITELLM_UI_PATH" "$CUSTOM_TIKTOKEN_CACHE_DIR"
          exec ${lib.getExe pkgs.litellm} --host 127.0.0.1 --port ${toString cfg.router.port} \
            --config ${yaml.generate "litellm.yaml" cfg.router.settings}
        ''
      ];
      EnvironmentVariables = {
        LITELLM_NON_ROOT = "true";
        LITELLM_UI_PATH = "${home}/Library/Application Support/litellm/ui";
        CUSTOM_TIKTOKEN_CACHE_DIR = "${home}/Library/Caches/litellm/tiktoken";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/litellm.log";
      StandardErrorPath = "/tmp/litellm.log";
    };

    # Open WebUI, like NixOS' services.open-webui: its data in Application
    # Support (its own chats, separate from zephyrus').
    launchd.user.agents.open-webui = mkIf cfg.webui.enable {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          ''
            mkdir -p "$DATA_DIR" "$STATIC_DIR"
            exec ${lib.getExe pkgs.open-webui} serve --host 127.0.0.1 --port ${toString cfg.webui.port}
          ''
        ];
        EnvironmentVariables =
          let
            dir = "${home}/Library/Application Support/open-webui";
          in
          cfg.webui.environment
          // {
            DATA_DIR = "${dir}/data";
            STATIC_DIR = "${dir}/static";
            HF_HOME = "${dir}/hf_home";
            SENTENCE_TRANSFORMERS_HOME = "${dir}/transformers_home";
          };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/open-webui.log";
        StandardErrorPath = "/tmp/open-webui.log";
      };
    };

    launchd.user.agents.llama-swap.serviceConfig = {
      ProgramArguments = [
        (lib.getExe pkgs.llama-swap)
        "--listen=127.0.0.1:${toString cfg.port}" # reached through the reverse proxy
        "--config=${yaml.generate "llama-swap.yaml" cfg.settings}"
      ];
      # Operations MPS lacks run on the CPU instead of failing.
      EnvironmentVariables.PYTORCH_ENABLE_MPS_FALLBACK = "1";
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/llama-swap.log";
      StandardErrorPath = "/tmp/llama-swap.log";
    };

    launchd.daemons.iogpu-wired-limit = mkIf (cfg.gpuMemoryMB != null) {
      serviceConfig = {
        ProgramArguments = [
          "/usr/sbin/sysctl"
          "iogpu.wired_limit_mb=${toString cfg.gpuMemoryMB}"
        ];
        RunAtLoad = true;
      };
    };
  };
}
