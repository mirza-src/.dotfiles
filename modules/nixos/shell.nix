# NixOS half of modules.shell (declared in ../common/shell.nix): zsh as every
# user's login shell.
{
  lib,
  pkgs,
  config,
  ...
}:
{
  config = lib.mkIf config.modules.shell.enable {
    users.defaultUserShell = pkgs.zsh;
  };
}
