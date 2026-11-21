# Amphetamine-style keep-awake: KeepingYouAwake in the menu bar, and while it
# is active the Mac also stays awake with the lid closed (on battery too).
#
# KeepingYouAwake only runs /usr/bin/caffeinate as a child, and caffeinate's
# assertions don't stop sleep on lid close. So a root daemon follows power
# assertion events and sets `pmset disablesleep` while that child runs (what
# Amphetamine's closed-display mode does). Anyone else's caffeinate (Claude
# Code, scripts) is ignored. The daemon also clears the flag at boot, so a
# crash can't leave the Mac unable to sleep.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.keep-awake;
  app = "${pkgs.keepingyouawake}/Applications/KeepingYouAwake.app";

  # Event-driven: `pmset -g assertionslog` prints a line whenever a power
  # assertion is created or released, so this only wakes when caffeinate
  # starts or stops. `script` gives pmset a tty, or it buffers its output.
  watch = pkgs.writeShellScript "keep-awake-lid" ''
    sync() {
      want=0
      for kya in $(/usr/bin/pgrep -x KeepingYouAwake); do
        if /usr/bin/pgrep -P "$kya" -x caffeinate >/dev/null; then
          want=1
        fi
      done
      have=$(/usr/bin/pmset -g | /usr/bin/awk '/SleepDisabled/ { print $2 }')
      if [ "''${have:-0}" != "$want" ]; then
        /usr/bin/pmset -a disablesleep "$want"
      fi
    }

    sync
    /usr/bin/script -q /dev/null /usr/bin/pmset -g assertionslog |
      while IFS= read -r line; do
        case "$line" in
          *caffeinate*)
            sleep 1 # let an exiting caffeinate leave the process table
            sync
            ;;
        esac
      done
  '';
in
{
  options.modules.keep-awake.enable = lib.mkEnableOption "KeepingYouAwake, also keeping the Mac awake with the lid closed";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.keepingyouawake ];

    # Started here; the app's own "Start at Login" can't register an app in
    # the nix store.
    launchd.user.agents.keepingyouawake.serviceConfig = {
      ProgramArguments = [ "${app}/Contents/MacOS/KeepingYouAwake" ];
      RunAtLoad = true;
    };

    launchd.daemons.keep-awake-lid.serviceConfig = {
      ProgramArguments = [ "${watch}" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
