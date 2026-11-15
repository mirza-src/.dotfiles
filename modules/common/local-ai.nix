# Local LLMs (and ComfyUI) behind llama-swap, on NixOS and macOS. One model
# catalog for both machines; ../nixos/local-ai.nix and ../darwin/local-ai.nix
# run it.
#
# llama-swap starts llama-server for whichever model a request names, or
# ComfyUI, one at a time: whatever was used last holds the GPU, until
# `idleUnload` seconds without requests. It listens on localhost only; the
# reverse proxy (modules.reverse-proxy) is the way in:
#
#   http://<host>/             Open WebUI (webui), its own chats per machine
#   http://<host>/llm/v1/...   Anthropic and OpenAI API: a router (LiteLLM)
#                              picks the machine per session and request,
#                              see `routing`; clients never pick one
#   http://<host>/comfyui/     this machine's ComfyUI (imageGen), started on
#                              first use
#   http://localhost:9292/ui   llama-swap's dashboard (on the machine itself)
#
# Model files, the LLMs and ComfyUI's (comfyui.models), are downloaded ahead
# of time by a service (llama-models on NixOS, a launchd agent on macOS) that
# runs `pullCommand` at boot/login and whenever the catalog changes, retrying
# while offline; a model whose file isn't there yet fails to load until it is.
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.local-ai;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  host = config.networking.hostName;

  settingsFormat = pkgs.formats.yaml { };

  llamaServer = "${cfg.llamaCpp}/bin/llama-server";

  # Files land in <modelDir>/<repo>/<file>.
  fileIn = m: name: "${cfg.modelDir}/${m.repo}/${name}";

  # ComfyUI's files land in <modelDir>/comfyui/<repo>/<file>.
  comfyModelDir = repo: "${cfg.modelDir}/comfyui/${repo}";

  pullCommand = pkgs.writeShellScript "llama-models-pull" ''
    # hf's own cache and token next to the models, not in $HOME.
    export HF_HOME=${cfg.modelDir}/.hf HF_HUB_DISABLE_TELEMETRY=1
    status=0
    pull() { # repo dir files...
      local repo=$1 dir=$2
      shift 2
      ${lib.getExe pkgs.huggingface-cli} download "$repo" "$@" --local-dir "$dir" || status=1
    }
    ${lib.concatMapStrings (m: ''
      pull ${m.repo} ${cfg.modelDir}/${m.repo} ${
        lib.escapeShellArgs ([ m.file ] ++ lib.optional (m.mmproj != null) m.mmproj)
      }
    '') (lib.attrValues cfg.models)}
    ${lib.optionalString cfg.imageGen.enable (
      lib.concatMapStrings (m: ''
        pull ${m.repo} ${comfyModelDir m.repo} ${lib.escapeShellArg m.file}
      '') cfg.comfyui.models
    )}
    exit $status
  '';

  # ComfyUI with its state in comfyui.dataDir, seeded from the package the
  # way services.comfyui does. The downloaded models are found through an
  # extra model paths file (one entry per file, in its repo's layout); more
  # models and custom nodes can be installed from its UI (ComfyUI-Manager).
  comfyui = cfg.comfyui.package.override (old: {
    extraPackages =
      ps:
      (old.extraPackages or (_: [ ]) ps)
      ++ [
        ps.comfyui-manager
        # ComfyUI-GGUF's dependencies
        ps.gguf
        ps.sentencepiece
        ps.protobuf
      ];
  });
  comfyuiModelPaths = settingsFormat.generate "extra_model_paths.yaml" (
    lib.listToAttrs (
      lib.imap0 (
        i: m:
        lib.nameValuePair "model${toString i}" {
          base_path = comfyModelDir m.repo;
          ${m.dir} = dirOf m.file;
        }
      ) cfg.comfyui.models
    )
  );
  comfyuiStart = pkgs.writeShellScript "comfyui-start" ''
    dir=${lib.escapeShellArg cfg.comfyui.dataDir}
    for d in custom_nodes input output models; do
      if [[ ! -d $dir/$d ]]; then
        mkdir -p "$dir"
        ${pkgs.coreutils}/bin/cp --no-preserve=all -r ${comfyui}/share/comfyui/$d "$dir/"
      fi
    done
    mkdir -p "$dir/user"
    ln -sfn ${inputs.comfyui-gguf} "$dir/custom_nodes/ComfyUI-GGUF"
    exec ${lib.getExe comfyui} --base-directory="$dir" \
      --database-url="sqlite:///$dir/user/comfyui.db" \
      --extra-model-paths-config=${comfyuiModelPaths} \
      --listen=127.0.0.1 --port="$1" --enable-manager
  '';

  modelSettings =
    _: m:
    {
      cmd = concatStringsSep " " (
        [
          llamaServer
          "--host 127.0.0.1"
          "--port \${PORT}"
          "--model ${fileIn m m.file}"
          "--ctx-size ${toString m.contextSize}"
          "--parallel 1"
          "--jinja"
          # Halves the KV cache; lets more of the model stay on the GPU.
          "--cache-type-k q8_0"
          "--cache-type-v q8_0"
          "--no-webui"
          # No -ngl/--n-cpu-moe: llama.cpp's --fit (on by default) puts as
          # many layers and MoE experts on the GPU as the free VRAM allows
          # and the rest in RAM, so it adapts to what else is using the GPU.
        ]
        # Image input.
        ++ lib.optional (m.mmproj != null) "--mmproj ${fileIn m m.mmproj}"
        ++ m.extraArgs
      );
      inherit (m) aliases;
      name = m.displayName;
      ttl = cfg.idleUnload;
    }
    // lib.optionalAttrs (m.description != "") { inherit (m) description; };

  settings = {
    # Loading 25 GB from disk, or starting ComfyUI, takes a while.
    healthCheckTimeout = 600;
    logLevel = "info";
    includeAliasesInList = true;
    models =
      mapAttrs modelSettings cfg.models
      # llama-swap's /comfyui/ endpoint serves exactly this model ID, and
      # keeps the open tab from holding or reloading it.
      // lib.optionalAttrs cfg.imageGen.enable {
        comfyui_auto = {
          cmd = "${comfyuiStart} \${PORT}";
          checkEndpoint = "/"; # no /health
          ttl = cfg.idleUnload;
          unlisted = true; # not a chat model
        };
      };
  };

  # /llm routing, the same on every machine:
  #
  #  1. Caddy sends /llm/... to the router (LiteLLM) of the first of
  #     `machines` that is up (X-LLM-Route), so one router sees every
  #     request; the clients' session IDs go along as LiteLLM's.
  #  2. The router picks a machine for the model: a session stays on the
  #     machine that served it (its prompt cache is there); a new one, or one
  #     whose machine is busy, gets the first machine with no request for
  #     that model running (max_parallel_requests 1, in `machines` order). If
  #     every machine is busy: 429, which clients retry.
  #  3. That machine's Caddy (X-LLM-Local) hands it to its llama-swap, or
  #     answers 503 while ComfyUI holds its GPU (its /running lists no
  #     catalog model), and the router tries the next machine.
  #
  # Everything speaks the Anthropic Messages API end to end (llama-swap
  # serves it), so nothing is translated; Open WebUI's OpenAI requests are.
  llamaSwap = "127.0.0.1:${toString cfg.port}";
  machineURL = m: if m == host then "http://127.0.0.1" else "http://${m}";
  routerDial = m: if m == host then "127.0.0.1:80" else "${m}:80";
  # LiteLLM insists on a key; it only listens on localhost, Caddy adds it.
  routerKey = "sk-local-llm";
  internal = config.modules.reverse-proxy.privateRanges;
  freeBody = "\"running\":\\[(\\]|.\"model\":\"(${concatStringsSep "|" (map lib.escapeRegex (lib.attrNames cfg.models))})\")";

  routerSettings = {
    model_list = lib.concatLists (
      lib.imap1 (
        order: m:
        lib.concatLists (
          lib.mapAttrsToList (
            id: model:
            map (name: {
              model_name = name;
              litellm_params = {
                model = "anthropic/${id}";
                api_base = machineURL m;
                api_key = "none";
                extra_headers.X-LLM-Local = "1";
                inherit order;
                max_parallel_requests = 1;
                # A cold model loads for a while; generations run long.
                timeout = 1800;
              };
            }) ([ id ] ++ model.aliases)
          ) cfg.models
        )
      ) cfg.machines
    );
    router_settings = {
      optional_pre_call_checks = [ "session_affinity" ];
      deployment_affinity_ttl_seconds = 3600;
    };
    litellm_settings = {
      telemetry = false;
      drop_params = true; # OpenAI parameters Anthropic has no equivalent for
    };
    general_settings.master_key = routerKey;
  };

  routing = ''
    # The hops between machines: only from this machine and the tailnet
    # (the router hop adds LiteLLM's admin key).
    @llm-local {
      header X-LLM-Local 1
      remote_ip ${internal}
    }
    handle @llm-local {
      reverse_proxy ${llamaSwap} {
        health_uri /running
        health_body `${freeBody}`
        health_interval 3s
        flush_interval -1
      }
    }

    @llm-route {
      header X-LLM-Route 1
      remote_ip ${internal}
    }
    handle @llm-route {
      reverse_proxy 127.0.0.1:${toString cfg.router.port} {
        header_up Authorization "Bearer ${routerKey}"
        header_up -X-Api-Key
        flush_interval -1
      }
    }

    handle_path /llm/* {
      @claude header X-Claude-Code-Session-Id *
      request_header @claude X-Litellm-Session-Id {header.X-Claude-Code-Session-Id}
      @opencode header X-Session-Affinity *
      request_header @opencode X-Litellm-Session-Id {header.X-Session-Affinity}
      reverse_proxy ${concatStringsSep " " (map routerDial cfg.machines)} {
        header_up X-LLM-Route 1
        lb_policy first
        lb_try_duration 5s
        health_uri /health/liveliness
        health_headers {
          X-LLM-Route 1
        }
        health_interval 5s
        health_timeout 3s
        flush_interval -1
      }
    }
  '';
in
{
  options.modules.local-ai = {
    enable = mkEnableOption "local LLMs served by llama-swap";

    port = mkOption {
      type = types.port;
      default = 9292;
      description = "Port llama-swap listens on (OpenAI and Anthropic API).";
    };

    idleUnload = mkOption {
      type = types.ints.unsigned;
      default = 1800;
      description = "Seconds without requests before a model is unloaded and its memory freed.";
    };

    llamaCpp = mkOption {
      type = types.package;
      default = pkgs.llama-cpp;
      defaultText = lib.literalExpression "pkgs.llama-cpp (Metal on macOS)";
      description = "llama.cpp build that provides llama-server; the NixOS half picks one for modules.local-ai.gpuAcceleration.";
    };

    machines = mkOption {
      type = types.listOf types.str;
      default = [ host ];
      example = [
        "zephyrus"
        "macbook-pro"
      ];
      description = ''
        Machines running this catalog (their MagicDNS names), the preferred
        one first: /llm goes to the first that is up.
      '';
    };

    webui = {
      enable = mkEnableOption "Open WebUI (chat UI for the local models) at http://<host>/" // {
        default = true;
      };
      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Its port on localhost (reached through the reverse proxy).";
      };
      environment = mkOption {
        type = types.attrsOf types.str;
        readOnly = true;
        internal = true;
        description = "Its settings, the same on every platform.";
        default = {
          ENABLE_OLLAMA_API = "False";
          # Routed like every client, so its requests count towards "busy".
          OPENAI_API_BASE_URL = "http://127.0.0.1/llm/v1";
          OPENAI_API_KEY = "none"; # the proxy adds the router's key
          # Same model as the chat, so title/tag generation doesn't swap
          # the loaded model out.
          TASK_MODEL_EXTERNAL = "coder";
          # Single user on a private tailnet.
          WEBUI_AUTH = "False";
          # No telemetry (services.open-webui's defaults, which this replaces).
          SCARF_NO_ANALYTICS = "True";
          DO_NOT_TRACK = "True";
          ANONYMIZED_TELEMETRY = "False";
        };
      };
    };

    imageGen = {
      enable = mkEnableOption "ComfyUI for image and video generation, at http://<host>/comfyui/";
    };

    comfyui = {
      package = mkOption {
        type = types.package;
        default = pkgs.comfyui;
        defaultText = lib.literalExpression "pkgs.comfyui";
        description = "ComfyUI build (the NixOS half picks a CUDA one).";
      };
      dataDir = mkOption {
        type = types.str;
        description = "ComfyUI's models, custom nodes, inputs and outputs (set per platform).";
      };
      models = mkOption {
        description = ''
          ComfyUI models downloaded ahead of time (with the LLMs), each a
          file in a Hugging Face repo and the ComfyUI model type it is.
        '';
        type = types.listOf (
          types.submodule {
            options = {
              repo = mkOption { type = types.str; };
              file = mkOption {
                type = types.str;
                description = "Path in `repo`.";
              };
              dir = mkOption {
                type = types.enum [
                  "diffusion_models"
                  "text_encoders"
                  "vae"
                  "loras"
                ];
                description = "ComfyUI model type (models/ subfolder) it belongs to.";
              };
            };
          }
        );
        # Qwen-Image-2512 (images) and Wan 2.2 5B (video, text or image to
        # video): the files ComfyUI's own templates for them load. macOS
        # can't run fp8 weights (no fp8 on MPS), so it gets GGUF versions
        # (ComfyUI-GGUF's "Unet Loader (GGUF)" / "CLIPLoader (GGUF)" nodes
        # in place of the templates' loaders); same VAEs.
        default =
          let
            qwen = "Comfy-Org/Qwen-Image";
            wan = "Comfy-Org/Wan-2.2";
          in
          [
            {
              repo = qwen;
              file = "split_files/vae/qwen_image_vae.safetensors";
              dir = "vae";
            }
            {
              repo = wan;
              file = "split_files/vae/wan2.2_vae.safetensors";
              dir = "vae";
            }
          ]
          ++ (
            if isDarwin then
              [
                {
                  repo = "unsloth/Qwen-Image-2512-GGUF";
                  file = "qwen-image-2512-Q4_K_M.gguf"; # 13.2 GB
                  dir = "diffusion_models";
                }
                {
                  repo = "unsloth/Qwen2.5-VL-7B-Instruct-GGUF";
                  file = "Qwen2.5-VL-7B-Instruct-Q8_0.gguf"; # 8 GB
                  dir = "text_encoders";
                }
                {
                  # Next to it: the loader looks for it (Qwen-Image-Edit).
                  repo = "unsloth/Qwen2.5-VL-7B-Instruct-GGUF";
                  file = "mmproj-F16.gguf"; # 1.3 GB
                  dir = "text_encoders";
                }
                {
                  repo = "QuantStack/Wan2.2-TI2V-5B-GGUF";
                  file = "Wan2.2-TI2V-5B-Q8_0.gguf"; # 5.4 GB
                  dir = "diffusion_models";
                }
                {
                  repo = "city96/umt5-xxl-encoder-gguf";
                  file = "umt5-xxl-encoder-Q8_0.gguf"; # 6 GB
                  dir = "text_encoders";
                }
              ]
            else
              [
                {
                  repo = qwen;
                  file = "split_files/diffusion_models/qwen_image_2512_fp8_e4m3fn.safetensors"; # 20.4 GB
                  dir = "diffusion_models";
                }
                {
                  repo = qwen;
                  file = "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"; # 9.3 GB
                  dir = "text_encoders";
                }
                {
                  repo = wan;
                  file = "split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors"; # 9.9 GB
                  dir = "diffusion_models";
                }
                {
                  repo = wan;
                  file = "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"; # 6.7 GB
                  dir = "text_encoders";
                }
              ]
          );
      };
    };

    models = mkOption {
      description = ''
        Model catalog: model ID -> GGUF on Hugging Face. Clients use the ID or
        an alias (`coder`, `small`), so swapping the model behind an alias
        needs no client change.
      '';
      type = types.attrsOf (
        types.submodule {
          options = {
            repo = mkOption {
              type = types.str;
              example = "unsloth/Qwen3.6-35B-A3B-GGUF";
              description = "Hugging Face repository.";
            };
            file = mkOption {
              type = types.str;
              example = "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf";
              description = "GGUF file in `repo` (one quantisation).";
            };
            mmproj = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "mmproj-F16.gguf";
              description = "Vision projector in `repo`, for image input.";
            };
            displayName = mkOption {
              type = types.str;
              default = "";
            };
            description = mkOption {
              type = types.str;
              default = "";
            };
            aliases = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
            contextSize = mkOption {
              type = types.ints.positive;
              # Claude Code's system prompt alone is ~25k tokens.
              default = 65536;
            };
            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Extra llama-server arguments (sampling, etc.).";
            };
          };
        }
      );
      default = {
        # Best open coding model for 32 GB right now (Nov 2026): SWE-bench
        # Verified 73.4, 35B total / 3B active, so it runs at interactive
        # speed with its experts in RAM (zephyrus) or on an M1 Pro.
        "qwen3.6-35b-a3b" = {
          repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
          file =
            if isDarwin then
              # 17.7 GB: leaves the Mac room for apps besides the model.
              "Qwen3.6-35B-A3B-UD-IQ4_XS.gguf"
            else
              "Qwen3.6-35B-A3B-UD-Q4_K_XL.gguf"; # 22.4 GB
          mmproj = "mmproj-F16.gguf"; # 0.9 GB
          displayName = "Qwen3.6 35B-A3B";
          description = "Main coding agent model";
          aliases = [ "coder" ];
          # Qwen's recommended sampling for coding (thinking mode).
          extraArgs = [
            "--temp 0.6"
            "--top-p 0.95"
            "--top-k 20"
            "--min-p 0"
          ];
        };
        # Challenger: Recursive Flint (Oct 2026), 40B / 2.5B active, vendor
        # SWE-bench Verified 74.2. Not yet independently benchmarked.
        flint = {
          repo = "unsloth/flint-GGUF";
          file =
            if isDarwin then
              "flint-UD-Q3_K_XL.gguf" # 18.5 GB
            else
              "flint-UD-Q4_K_XL.gguf"; # 25 GB
          displayName = "Recursive Flint 40B-A2.5B";
          description = "Coding agent model (challenger)";
        };
        # Fits entirely in VRAM: quick edits, chat, Open WebUI tasks.
        "qwen3.5-9b" = {
          repo = "unsloth/Qwen3.5-9B-GGUF";
          file = "Qwen3.5-9B-UD-Q4_K_XL.gguf"; # 6 GB
          mmproj = "mmproj-F16.gguf";
          displayName = "Qwen3.5 9B";
          description = "Small fast model";
          aliases = [ "small" ];
        };
      };
    };

    modelDir = mkOption {
      type = types.str;
      description = "Where the model files are downloaded to (set per platform).";
    };

    router = {
      port = mkOption {
        type = types.port;
        default = 4000;
        description = "Port of the router (LiteLLM) on localhost.";
      };
      settings = mkOption {
        inherit (settingsFormat) type;
        readOnly = true;
        internal = true;
        default = routerSettings;
        description = "Generated LiteLLM configuration.";
      };
    };

    pullCommand = mkOption {
      type = types.path;
      readOnly = true;
      internal = true;
      default = pullCommand;
      description = "Downloads (or updates) every catalog model into modelDir.";
    };

    settings = mkOption {
      inherit (settingsFormat) type;
      readOnly = true;
      internal = true;
      default = settings;
      description = "Generated llama-swap settings (for services.llama-swap.settings).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.elem host cfg.machines;
        message = "modules.local-ai.machines must include this machine (${host}).";
      }
    ];

    environment.systemPackages = [
      cfg.llamaCpp # llama-cli, llama-bench for trying models by hand
    ];

    modules.reverse-proxy = {
      enable = true;
      # Open WebUI can't run under a sub-path.
      routes."/" = mkIf cfg.webui.enable { to = "127.0.0.1:${toString cfg.webui.port}"; };
      routes."/comfyui" = mkIf cfg.imageGen.enable {
        to = llamaSwap;
        strip = false; # llama-swap's own /comfyui/ endpoint
      };
      extraConfig = routing;
    };
  };
}
