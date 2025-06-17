{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.shell;
in
{
  options.modules.shell = {
    enable = mkEnableOption "Enable shell utilities and configurations";
  };

  config = mkIf cfg.enable {
    programs.direnv.enable = true;
    programs.fzf.keybindings = true;
    programs.fzf.fuzzyCompletion = true;
    users.defaultUserShell = pkgs.zsh;
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      autosuggestions.strategy = [ "match_prev_cmd" ];
      enableBashCompletion = true;
      enableLsColors = true;
      syntaxHighlighting.enable = true;
      vteIntegration = true;
      histSize = 100000;
      ohMyZsh.enable = true;
      ohMyZsh.plugins = [
        "fzf"
      ];
    };
    programs.tmux = {
      enable = true;
      baseIndex = 1;
      clock24 = true;
      keyMode = "vi";
      escapeTime = 600;
      customPaneNavigationAndResize = true;
      plugins = with pkgs.tmuxPlugins; [
        sensible
        vim-tmux-navigator
        catppuccin
        yank
        better-mouse-mode
      ];
      extraConfig = ''
        set-option -g default-shell ${pkgs.zsh}/bin/zsh
      '';
    };
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withNodeJs = true;
      withPython3 = true;
    };
  };
}
