# System side of the shell, shared by NixOS and macOS: a system zsh that sets
# up the Nix environment (/etc/zshrc) and completions for system packages. The
# shell setup itself (oh-my-zsh, autosuggestions, tmux, neovim, direnv, fzf,
# starship) is the home-manager module of the same name. The NixOS half
# (../nixos/shell.nix) also makes zsh every user's login shell; macOS already
# defaults to zsh.
{ lib, config, ... }:
let
  cfg = config.modules.shell;
in
{
  options.modules.shell.enable = lib.mkEnableOption "zsh as the system shell";

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = true;
    # Completions for system packages, for home-manager's zsh.
    environment.pathsToLink = [ "/share/zsh" ];
  };
}
