# Shell setup, identical on Linux and macOS: zsh (oh-my-zsh, autosuggestions,
# syntax highlighting), fzf, direnv, tmux, neovim and starship. On NixOS the
# host's modules.shell makes zsh the login shell.
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
  options.modules.shell.enable = lib.mkEnableOption "shell utilities and configuration";

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion = {
        enable = true;
        strategy = [ "match_prev_cmd" ];
      };
      syntaxHighlighting.enable = true;
      enableVteIntegration = pkgs.stdenv.hostPlatform.isLinux;
      history = {
        size = 100000;
        save = 100000;
      };
      oh-my-zsh = {
        enable = true;
        plugins = [ "fzf" ];
      };
    };
    programs.dircolors.enable = true; # coloured ls

    programs.fzf.enable = true; # key bindings and fuzzy completion
    programs.direnv.enable = true;

    programs.tmux = {
      enable = true;
      baseIndex = 1;
      clock24 = true;
      keyMode = "vi";
      escapeTime = 600;
      customPaneNavigationAndResize = true;
      shell = "${pkgs.zsh}/bin/zsh";
      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        catppuccin
        yank
        better-mouse-mode
      ];
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
    };

    programs.starship = {
      enable = true;
      settings = fromTOML (builtins.readFile ./.config/starship.toml);
    };
  };
}
