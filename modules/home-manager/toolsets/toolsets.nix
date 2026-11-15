# Toolsets: sets of tools from ./toolsets in this repo, switched on from any
# directory with `tools use ai frontend` (see tools.sh). Each switch is a
# generation of the Nix profile ~/.local/state/nix/profiles/tools, built from
# the flake (legacyPackages.<system>.toolsets); home-manager only installs
# the command and the shell hooks (bash, zsh, fish), which load a switch by
# themselves at the next prompt.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.programs.toolsets;

  tools = pkgs.writeShellApplication {
    name = "tools";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
    ];
    runtimeEnv.TOOLS_SYSTEM = pkgs.stdenv.hostPlatform.system;
    text = builtins.readFile ./tools.sh;
  };
  exe = lib.getExe tools;
  # $HOME, expanded by the shells.
  profile = "$HOME/.local/state/nix/profiles/tools";
in
{
  options.programs.toolsets = {
    enable = lib.mkEnableOption "the `tools` command for switching toolsets";

    default = lib.mkOption {
      type = lib.types.listOf (lib.types.enum self.lib.toolsetNames);
      default = [ ];
      example = [ "frontend" ];
      description = ''
        Toolsets switched to when this configuration (or specialisation) is
        activated and its default differs from the last one applied, so
        switching specialisations changes them while a plain rebuild keeps
        what `tools` switched to. Built with the home configuration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ tools ];

    home.activation.toolsetsDefault =
      let
        # Its attribute name in mkToolsets: the names in toolsetNames order.
        names = lib.filter (n: lib.elem n cfg.default) self.lib.toolsetNames;
        key = if names == [ ] then "none" else lib.concatStringsSep "+" names;
        toolset = (self.lib.mkToolsets pkgs).${key};
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _toolsets_state=$HOME/.local/state/tools/default
        if [[ "$(cat "$_toolsets_state" 2>/dev/null)" != ${toolset} ]]; then
          run mkdir -p $HOME/.local/state/nix/profiles $HOME/.local/state/tools
          run nix-env --profile $HOME/.local/state/nix/profiles/tools --set ${toolset}
          run sh -c 'printf %s "$1" > "$2"' _ ${toolset} "$_toolsets_state"
          verboseEcho "toolsets: ${key}"
        fi
      '';

    # Each shell: the profile's bin/ first on PATH, and `tools export` before
    # every prompt, which only prints something after a switch.
    programs.zsh.initContent = lib.mkMerge [
      # Completions from the toolsets, before compinit.
      (lib.mkOrder 550 ''
        fpath=(${profile}/share/zsh/site-functions $fpath)
      '')
      ''
        path=(${profile}/bin ''${path:#${profile}/bin})
        _tools_hook() { eval "$(${exe} export zsh)"; }
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd _tools_hook
        _tools_hook
      ''
      (builtins.replaceStrings
        [ "@toolsets@" ]
        [
          (lib.concatMapStringsSep " " lib.escapeShellArg self.lib.toolsetNames)
        ]
        (builtins.readFile ./completion.zsh)
      )
    ];
    programs.bash.initExtra = ''
      case ":$PATH:" in
        *":${profile}/bin:"*) ;;
        *) PATH="${profile}/bin:$PATH" ;;
      esac
      _tools_hook() { eval "$(${exe} export bash)"; }
      PROMPT_COMMAND="_tools_hook''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
      _tools_hook
    '';
    programs.fish.interactiveShellInit = ''
      fish_add_path --path --prepend --move ${profile}/bin
      function _tools_hook --on-event fish_prompt
        ${exe} export fish | source
      end
      _tools_hook
    '';
  };
}
