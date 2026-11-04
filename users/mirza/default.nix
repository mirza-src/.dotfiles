# Shared home-manager config for every platform. Platform-specific bits live
# in ./linux.nix and ./darwin.nix (each a no-op on the other platform).
# Dotfiles live in ./.config; each layer lists the folders it links.
{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./linux.nix
    ./darwin.nix
  ];

  modules.defaults.enable = true;
  modules.giantswarm.enable = true;
  modules.kubernetes.enable = true;
  modules.vpn.enable = true;
  modules.shell.enable = true; # zsh, tmux, neovim, direnv, fzf, starship

  programs.home-manager.enable = true;
  programs.claude-code.enable = true;
  programs.zsh.enable = true;
  programs.git = {
    enable = true;
    signing.signByDefault = true;
    signing.format = "ssh";
    settings = {
      gpg.ssh.defaultKeyCommand = "ssh-add -L";
      user.name = "Mirza Esaaf Shuja";
      user.email = "mirzaesaaf@gmail.com";
      core.filemode = false;
      push.autoSetupRemote = true;
    };
  };

  programs.ssh-agent-switch = {
    enable = true;
    defaultAgent = "bitwarden";
    agents.bitwarden = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
  };

  programs.firefox.enable = true;
  programs.lapce.enable = true;
  programs.zed-editor.enable = true;

  programs.obsidian = {
    enable = true;
    defaultSettings.corePlugins = [
      "audio-recorder"
      "backlink"
      "bookmarks"
      "canvas"
      "command-palette"
      "daily-notes"
      "editor-status"
      "file-explorer"
      "file-recovery"
      "global-search"
      "graph"
      "markdown-importer"
      "note-composer"
      "outgoing-link"
      "outline"
      "page-preview"
      "properties"
      # "publish"
      "random-note"
      "slash-command"
      "slides"
      "switcher"
      # "sync"
      "tag-pane"
      "templates"
      "word-count"
      "workspaces"
      "zk-prefixer"
    ];
    defaultSettings.communityPlugins = with pkgs.obsidian-plugins; [
      github-embeds
      shiki
    ];

    vaults.tinkering = {
      enable = true;
      target = "Documents/tinkering";
    };
  };

  # Package: plain VS Code here; Linux swaps in the FHS build (linux.nix).
  programs.vscode = {
    enable = true;
    # mutableExtensionsDir = false;

    profiles.default.extensions = (
      with pkgs.nix-vscode-extensions.vscode-marketplace;
      [
        github.copilot-chat
        anthropic.claude-code

        ms-azuretools.vscode-containers
        ms-vscode.vscode-speech
        ms-vscode-remote.remote-containers
        jnoortheen.nix-ide
        christian-kohler.path-intellisense
        mkhl.direnv
        github.vscode-github-actions
        eamodio.gitlens
        gruntfuggly.todo-tree
        usernamehw.errorlens
        esbenp.prettier-vscode
        redhat.vscode-yaml
        redhat.vscode-xml
        ms-python.python
        golang.go
        dbaeumer.vscode-eslint
        bradlc.vscode-tailwindcss
        ms-kubernetes-tools.vscode-kubernetes-tools
        tamasfe.even-better-toml

        # C/C++
        ms-vscode.makefile-tools
        ms-vscode.cpptools-extension-pack
        ms-vscode.cmake-tools
        ms-vscode.cpptools
        ms-vscode.cpptools-themes

        # Java
        vscjava.vscode-java-pack
        redhat.java
        vscjava.vscode-maven
        vscjava.vscode-gradle
        vscjava.vscode-java-test
        vscjava.vscode-java-debug
        vscjava.vscode-java-dependency

        haskell.haskell
        tomoki1207.pdf
        hashicorp.hcl
        hashicorp.terraform
        ms-vscode.wordcount
        theqtcompany.qt-core
        theqtcompany.qt-qml

        svelte.svelte-vscode

        google.selinux-policy-languages
      ]
    );
  };

  home.packages = with pkgs; [
    wget
    curl

    rclone
    catppuccin

    # Graphical applications
    discord
    google-chrome
    mailspring
    kitty
    slack
    postman
    bitwarden-desktop
    bitwarden-cli
    lite-xl

    # TODO: Move to project-specific devenv configurations
    (haskellPackages.ghcWithPackages (
      pkgs: with pkgs; [
        QuickCheck
        cabal-install
      ]
    ))
    haskell-language-server
    nodejs
    python3
    jdk
    glpk

    # Utilities
    bleachbit
    czkawka-full
    moodle-dl

    # (azure-cli.withExtensions [ azure-cli.extensions.ssh ])
    kubelogin
    ansible
  ];

  # Cross-platform app configs from ./.config (writable symlinks into this repo).
  xdg.configFile = config.lib.dotfiles.linkDirs [
    ./.config/ghostty
    ./.config/kitty
  ];
  home.file.".vscode/argv.json".source = config.lib.dotfiles.mkMutableSymlink ./.vscode/argv.json;
  home.file.".vscode-insiders/argv.json".source =
    config.lib.dotfiles.mkMutableSymlink ./.vscode/argv.json;
}
