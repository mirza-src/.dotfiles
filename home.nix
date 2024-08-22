{ config, pkgs, lib, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should manage.
  # Will be set in nix-darwin configuration.
  # home.username = "${username}";
  # home.homeDirectory = "/Users/${username}";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  fonts.fontconfig.enable = true;
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    git
    (nerdfonts.override { fonts = [ "FiraCode" "Meslo" ]; })
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mirza/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;


  programs.go = {
    enable = true;

    goPath = ".go";
  };

  programs.direnv = {
    enable = true;
  };

  programs.git = {
    enable = true;
    userName = "mirza-src";
    userEmail = "mirzaesaaf@gmail.com";
    aliases = {
      st = "status";
    };
    extraConfig = {
      github.user = "mirza-src";
      init = { defaultBranch = "main"; };
    };
    delta = {
      enable = true;
      options = {
        features = "line-numbers side-by-side decorations hyperlinks";
      };
    };
  };

  programs.fzf = {
    enable = true;
  };

  programs.zoxide = {
    enable = true;

    options = [
      "--cmd cd"
    ];
  };

  programs.eza = {
    enable = true;

    icons = true;
    git = true;
  };

  programs.bat = {
    enable = true;

    extraPackages = with pkgs.bat-extras; [ batgrep batman batpipe batwatch prettybat ];
  };

  programs.starship = {
    enable = true;

    enableTransience = true;
  };

  programs.zsh = {
    enable = true;

    autocd = true;

    enableCompletion = true;

    history = {
      extended = true;
    };

    autosuggestion = {
      enable = true;
      strategy = [ "match_prev_cmd" ];
    };

    syntaxHighlighting = {
      enable = true;
    };

    historySubstringSearch = {
      enable = true;
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    shellAliases = {
      ls = "eza --color=always";
      ll = "ls -lh";
      la = "ls -a";
      lla = "ls -lha";

      cat = "bat";
    };

    initExtra = ''
      # Homebrew setup
      if [[ $(uname -m) == 'arm64' ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      # disable sort when completing `git checkout`
      zstyle ':completion:*:git-checkout:*' sort false
      # set descriptions format to enable group support
      # NOTE: don't use escape sequences here, fzf-tab will ignore them
      zstyle ':completion:*:descriptions' format '[%d]'
      # set list-colors to enable filename colorizing
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
      zstyle ':completion:*' menu no
      # preview directory's content with eza when completing path
      zstyle ':fzf-tab:complete:*' fzf-preview 'eza --color=always --icons --git -1 $realpath'
      # switch group using `<` and `>`
      zstyle ':fzf-tab:*' switch-group '<' '>'
    '';
  };

  programs.vscode = {
    enable = true;

    mutableExtensionsDir = true;
    extensions = with pkgs.vscode-extensions; [
      github.copilot
      github.vscode-github-actions
      eamodio.gitlens
      ms-azuretools.vscode-docker
      visualstudioexptteam.vscodeintellicode
      gruntfuggly.todo-tree
      usernamehw.errorlens
      esbenp.prettier-vscode
      jnoortheen.nix-ide
      redhat.vscode-yaml
      redhat.vscode-xml
      ms-python.python
      golang.go
      dbaeumer.vscode-eslint
      bradlc.vscode-tailwindcss
      ms-kubernetes-tools.vscode-kubernetes-tools
      tamasfe.even-better-toml
    ];

    userSettings = builtins.fromJSON (builtins.readFile ./.vscode/settings.json);
  };

  launchd.agents = {
    colima = {
      enable = true;

      config = {
        EnvironmentVariables = {
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        ProgramArguments = [
          "${pkgs.colima}/bin/colima"
          "start"
          "-f"
        ];
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = true;
        };
        StandardErrorPath = "/Users/${config.home.username}/Library/Logs/nix-colima.log";
        StandardOutPath = "/Users/${config.home.username}/Library/Logs/nix-colima.log";
      };
    };
  };

  home.file.".colima" = {
    source = ./.colima;
    recursive = true;
  };

  home.file.".config" = {
    source = ./.config;
    recursive = true;
  };
}
