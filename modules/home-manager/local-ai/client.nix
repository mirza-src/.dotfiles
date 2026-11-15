# Client side of the local AI setup (servers: modules.local-ai on the hosts),
# on Linux and macOS. Configuration only, no scripts.
#
#   profile claude local|cloud    which backend `claude` uses from now on
#   profile claude local -- claude --continue
#                                 just this session (e.g. carry a Claude session
#                                 on locally when a limit is hit)
#   opencode      OpenCode on the local models
#
# `claude` always loads ~/.claude/profile.json on top of settings.json (or
# $CLAUDE_PROFILE, which `profile ... --` sets); the profile switch
# (modules/home-manager/profile-switch) links it to an empty file (cloud) or
# to the local-model settings below.
#
# Both clients talk to http://localhost/llm, the router of modules.local-ai:
# it picks a machine per session (see ../../common/local-ai.nix).
#
# Workflow: Matt Pocock's skills (flake input mattpocock-skills, in both
# Claude Code and OpenCode; `nix flake update mattpocock-skills` updates
# them). Once per repo /setup-matt-pocock-skills (picks the issue tracker:
# GitHub, or markdown files in .scratch/). Then in Claude: /grill-with-docs
# (or /grill-me for non-code plans), /to-spec, /to-tickets; and the tickets
# are implemented by /implement (one) or /implement-spec (all) — in
# OpenCode or `profile claude local -- claude` on the local model.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.local-ai-client;
  inherit (cfg) url;
  profileLink = "${config.programs.claude-code.configDir}/profile.json";

  # Claude profiles, layered on top of settings.json.
  profiles = {
    cloud = pkgs.writeText "claude-cloud.json" "{}";
    local = pkgs.writeText "claude-local.json" (
      builtins.toJSON {
        inherit (cfg) model;
        env = {
          ANTHROPIC_BASE_URL = url;
          ANTHROPIC_AUTH_TOKEN = "local"; # takes precedence over the subscription login
          ANTHROPIC_MODEL = cfg.model;
          # Every tier and subagents on one model: a model switch on a 12 GB
          # GPU means unloading and reloading ~20 GB.
          ANTHROPIC_DEFAULT_OPUS_MODEL = cfg.model;
          ANTHROPIC_DEFAULT_SONNET_MODEL = cfg.model;
          ANTHROPIC_DEFAULT_HAIKU_MODEL = cfg.model;
          CLAUDE_CODE_SUBAGENT_MODEL = cfg.model;
          CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
          # The real window of a model Claude Code doesn't know (it would
          # assume 1M), so it compacts before llama-server rejects a request.
          CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString cfg.contextSize;
          # A cold model may first load, or even download, for minutes.
          API_TIMEOUT_MS = "1800000";
        };
      }
    );
  };

  # `claude` with the active profile as an extra settings layer.
  claude = pkgs.symlinkJoin {
    name = "claude-code-${pkgs.claude-code.version}";
    inherit (pkgs.claude-code) version meta;
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude --add-flags '--settings "''${CLAUDE_PROFILE:-${profileLink}}"'
    '';
  };

  # Status line: model, context used, subscription limits with reset times.
  #   Opus 5.5 │ ctx 22% 45k/200k │ 5h 42% ↻2h │ wk 61% ↻3d
  #   ⌂ coder │ ctx 68% 45k/65k
  statusLine = ''
    jq -r '
      def left: (. - now) | if . >= 86400 then "\(. / 86400 | floor)d" else "\(. / 3600 | floor)h" end;
      def limit($name): select(.used_percentage) | "\($name) \(.used_percentage | floor)% ↻\(.resets_at // now | left)";
      ((.context_window.current_usage // {}) | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) as $used
      | (.context_window.context_window_size // 200000) as $size
      | [ (if $ENV.ANTHROPIC_BASE_URL then "⌂ \(.model.display_name)" else .model.display_name end),
          "ctx \($used * 100 / $size | floor)% \($used / 1000 | floor)k/\($size / 1000 | floor)k",
          (.rate_limits.five_hour // empty | limit("5h")),
          (.rate_limits.seven_day // empty | limit("wk"))
        ] | join(" │ ")'
  '';
  # The repo is a Claude Code plugin; its manifest lists the published skills
  # (skills/<category>/<name>), which OpenCode gets one by one.
  skillsRepo = inputs.mattpocock-skills;
  publishedSkills = lib.listToAttrs (
    map (
      dir: lib.nameValuePair (baseNameOf dir) "${skillsRepo}/${dir}"
    ) (lib.importJSON "${skillsRepo}/.claude-plugin/plugin.json").skills
  );

  localModel = name: output: {
    inherit name;
    tool_call = true;
    limit = {
      context = cfg.contextSize;
      inherit output;
    };
  };
in
{
  options.modules.local-ai-client = {
    enable = mkEnableOption "the claude cloud/local profiles, OpenCode and Matt Pocock's skills";

    url = mkOption {
      type = types.str;
      default = "http://localhost/llm";
      description = ''
        The local models' endpoint (without /v1): the router of
        modules.local-ai, which picks a machine per session and request.
      '';
    };

    model = mkOption {
      type = types.str;
      default = "coder";
      description = "Model (catalog ID or alias) the local claude profile and OpenCode start with.";
    };

    contextSize = mkOption {
      type = types.ints.positive;
      default = 65536;
      description = "Context window of the local models (modules.local-ai.models.*.contextSize).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.jq ]; # status line

    programs.profile-switch = {
      enable = true;
      switches.claude = {
        link = profileLink;
        options = lib.mapAttrs (_: toString) profiles;
        default = "cloud";
        env = "CLAUDE_PROFILE";
      };
    };

    programs.claude-code = {
      package = claude;
      # Merge into the writable settings.json, so /model, /config etc. can
      # still save there.
      mutableSettings = true;
      settings.statusLine = {
        type = "command";
        command = statusLine;
        refreshInterval = 60; # reset countdowns move while idle
      };
      # Personal skills (plain /grill-me etc.), the same set as OpenCode.
      skills = publishedSkills;
    };

    programs.opencode = {
      enable = true;
      settings = {
        model = "local/${cfg.model}";
        small_model = "local/${cfg.model}"; # same model: no reload for titles
        # The Anthropic API, like Claude Code: passed through to llama-swap
        # untranslated. The router's key is added by the proxy.
        provider.local = {
          npm = "@ai-sdk/anthropic";
          name = "Local";
          options = {
            baseURL = "${url}/v1";
            apiKey = "local";
          };
          models = {
            coder = localModel "Qwen3.6 35B-A3B" 16384;
            flint = localModel "Recursive Flint" 16384;
            small = localModel "Qwen3.5 9B" 8192;
          };
        };
      };
      skills = publishedSkills;
    };
  };
}
