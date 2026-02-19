{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.ssh-agent-switch;

  agentNames = lib.attrNames cfg.agents;
  agentList = lib.concatStringsSep " " agentNames;

  aliasName = lib.optionalString (cfg.alias != null) cfg.alias;
in
{
  options.programs.ssh-agent-switch = {
    enable = lib.mkEnableOption "Declarative SSH agent switching";

    agents = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Named SSH agents and their socket paths.";
      example = {
        bitwarden = "$HOME/.bitwarden-ssh-agent.sock";
        "1password" = "$HOME/.1password/agent.sock";
      };
    };

    defaultAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Agent to activate automatically on shell startup.";
    };

    alias = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "sas";
      description = "Optional short alias for ssh-agent-switch.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ssh-agent = {
      enableBashIntegration = lib.mkForce false;
      enableZshIntegration = lib.mkForce false;
      enableFishIntegration = lib.mkForce false;
      enableNushellIntegration = lib.mkForce false;
    };

    ## Single stable socket for everything
    systemd.user.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.ssh/agent.sock";
    home.activation.createSshDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.home.homeDirectory}/.ssh
    '';

    ## Main command
    home.packages = [
      (pkgs.writeShellScriptBin "ssh-agent-switch" ''
        set -euo pipefail

        TARGET="${config.home.homeDirectory}/.ssh/agent.sock"

        case "''${1:-}" in
        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: sock: ''
            ${name})
              SOCK="${sock}"
              ;;
          '') cfg.agents
        )}
          *)
            echo "Usage: ssh-agent-switch [${lib.concatStringsSep "|" agentNames}]"
            exit 1
            ;;
        esac

        if [ ! -S "$SOCK" ]; then
          echo "Socket not found: $SOCK"
          exit 1
        fi

        ln -sf "$SOCK" "$TARGET"
        echo "✓ Switched SSH agent to: $1"
      '')
    ];

    ## ---- ZSH COMPLETION ----
    programs.zsh.completionInit = ''
      _ssh_agent_switch() {
        local -a agents
        agents=(${agentList})
        _describe 'ssh agents' agents
      }
      compdef _ssh_agent_switch ssh-agent-switch ${aliasName}
    '';

    ## ---- BASH COMPLETION ----
    programs.bash.initExtra = ''
      _ssh_agent_switch() {
        COMPREPLY=($(compgen -W "${agentList}" -- "''${COMP_WORDS[1]}"))
      }
      complete -F _ssh_agent_switch ssh-agent-switch ${aliasName}
    ''
    ## ---- DEFAULT AGENT ----
    ++ (lib.optionalString (cfg.defaultAgent != null) ''
      if [ -S "${cfg.agents.${cfg.defaultAgent}}" ]; then
        ln -sf "${cfg.agents.${cfg.defaultAgent}}" "${config.home.homeDirectory}/.ssh/agent.sock"
      fi
    '');

    programs.zsh.initContent = lib.mkIf (cfg.defaultAgent != null) ''
      if [ -S "${cfg.agents.${cfg.defaultAgent}}" ]; then
        ln -sf "${cfg.agents.${cfg.defaultAgent}}" "${config.home.homeDirectory}/.ssh/agent.sock"
      fi
    '';

    ## ---- ALIAS ----
    home.shellAliases = lib.mkIf (cfg.alias != null) {
      "${cfg.alias}" = "ssh-agent-switch";
    };
  };
}
