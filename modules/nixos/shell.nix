# System side of the shell: zsh as every user's login shell. The shell setup
# itself (oh-my-zsh, autosuggestions, tmux, neovim, direnv, fzf, starship) is
# the home-manager module of the same name, ../home-manager/shell.nix, so it
# is identical on macOS.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.shell;
in
{
  options.modules.shell.enable = lib.mkEnableOption "zsh as the default login shell";

  config = lib.mkIf cfg.enable {
    # Needed system-wide for zsh to be a valid login shell.
    programs.zsh.enable = true;
    users.defaultUserShell = pkgs.zsh;
    # Completions for system packages, for home-manager's zsh.
    environment.pathsToLink = [ "/share/zsh" ];
  };
}
