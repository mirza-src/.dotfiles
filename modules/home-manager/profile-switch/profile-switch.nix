# Named profiles switched through a fixed link (see profile.sh for the
# command). A switch has a link that its consumers always read, the sources
# the link can point at, and the environment variable through which those
# consumers can be pointed at one source for a single command instead.
#
#   profile ssh bitwarden                    every new SSH connection
#   profile claude local                     every new `claude`
#   profile claude local -- claude -c        just this one, link unchanged
#
# Switches are declared where their consumers are configured: users/mirza
# (ssh, with session = true so GUI apps follow it too), local-ai/client.nix
# (claude).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    concatStringsSep
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.programs.profile-switch;

  configFile = pkgs.writeText "profile-switch.json" (builtins.toJSON cfg.switches);

  profile = pkgs.writeShellApplication {
    name = "profile";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
    ];
    runtimeEnv.PROFILE_SWITCH_CONFIG = "${configFile}";
    text = builtins.readFile ./profile.sh;
  };

  words = l: concatStringsSep " " (map lib.escapeShellArg l);

  sessionSwitches = lib.filterAttrs (_: s: s.session) cfg.switches;
  sessionVars = lib.mapAttrs' (_: s: lib.nameValuePair s.env s.link) (
    lib.filterAttrs (_: s: s.env != null) sessionSwitches
  );
  # Shell lines setting each session variable, from a (name: value: line).
  exports = line: lib.concatLines (mapAttrsToList line sessionVars);
  posixExport = n: v: ''export ${n}="${v}"'';
in
{
  options.programs.profile-switch = {
    enable = mkEnableOption "the `profile` command for switching named profiles";

    switches = mkOption {
      default = { };
      description = "Switches, by name (the first argument of `profile`).";
      type = types.attrsOf (
        types.submodule {
          options = {
            link = mkOption {
              type = types.str;
              example = "$HOME/.ssh/agent.sock";
              description = "The fixed path consumers read; `profile` points it at an option's source.";
            };
            options = mkOption {
              type = types.attrsOf types.str;
              description = "Option name -> source path. Shell expansions ($HOME, $(...)) are expanded at run time.";
            };
            default = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Option linked when it changed since last applied (so each
                home-manager specialisation can set its own), or when the
                link is missing or broken. Checked at activation and shell
                startup; a manual switch stays until then.
              '';
            };
            env = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "SSH_AUTH_SOCK";
              description = "Variable consumers read the path from, for `profile SWITCH OPTION -- COMMAND`.";
            };
            kind = mkOption {
              type = types.enum [
                "file"
                "socket"
              ];
              default = "file";
              description = "What a usable source is.";
            };
            session = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Point `env` at the link for the whole login session: shells,
                and GUI apps through the systemd user session (Linux) or
                launchd (macOS). Needs an absolute `link`.
              '';
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    assertions =
      mapAttrsToList (name: s: {
        assertion = s.default == null || s.options ? ${s.default};
        message = "programs.profile-switch.switches.${name}.default must be one of its options.";
      }) cfg.switches
      ++ mapAttrsToList (name: s: {
        assertion = s.env != null && lib.hasPrefix "/" s.link;
        message = "programs.profile-switch.switches.${name}.session needs `env` and an absolute `link`.";
      }) sessionSwitches;

    home.packages = [ profile ];

    # Session switches: their variable names the link everywhere.
    home.sessionVariables = sessionVars;
    # ...and again last in each shell's init, over whatever set it in
    # between (services.ssh-agent sets SSH_AUTH_SOCK there, for example).
    programs.bash.initExtra = lib.mkIf (sessionVars != { }) (lib.mkOrder 2000 (exports posixExport));
    programs.fish.interactiveShellInit = lib.mkIf (sessionVars != { }) (
      lib.mkOrder 2000 (exports (n: v: ''set -gx ${n} "${v}"''))
    );
    programs.nushell.extraConfig = lib.mkIf (sessionVars != { }) (
      lib.mkOrder 2000 (exports (n: v: ''$env.${n} = "${v}"''))
    );
    systemd.user.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isLinux sessionVars;
    launchd.agents = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.mapAttrs' (
        name: s:
        lib.nameValuePair "profile-switch-${name}" {
          enable = true;
          config = {
            ProgramArguments = [
              "/bin/launchctl"
              "setenv"
              s.env
              s.link
            ];
            RunAtLoad = true;
          };
        }
      ) sessionSwitches
    );

    # Defaults: at activation (files) and in each new shell (sockets appear
    # only once their agent runs).
    home.activation.profileSwitchInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe profile} --init
    '';
    programs.zsh.initContent = lib.mkMerge [
      (lib.mkIf (sessionVars != { }) (lib.mkOrder 2000 (exports posixExport)))
      ''
        ${lib.getExe profile} --init

        _profile() {
          if (( CURRENT == 2 )); then
            local -a switches=(${words (attrNames cfg.switches)})
            _describe 'switch' switches
          elif (( CURRENT == 3 )); then
            local -a opts
            case $words[2] in
              ${concatStringsSep "\n      " (
                mapAttrsToList (name: s: "${name}) opts=(${words (attrNames s.options)}) ;;") cfg.switches
              )}
            esac
            _describe 'option' opts
          elif (( CURRENT == 4 )); then
            compadd -- --
          else
            shift 4 words
            (( CURRENT -= 4 ))
            _normal
          fi
        }
        compdef _profile profile
      ''
    ];
  };
}
