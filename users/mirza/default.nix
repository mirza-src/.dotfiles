{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  mkMutableSymlink =
    path:
    config.lib.file.mkOutOfStoreSymlink (
      "${config.home.homeDirectory}/.dotfiles" + lib.removePrefix (toString inputs.self) (toString path)
    );

  listFilesRecursive =
    path:
    let
      pathType = builtins.readFileType path;
    in
    if pathType == "directory" then
      builtins.foldl' (acc: name: acc ++ listFilesRecursive (path + "/${name}")) [ ] (
        builtins.attrNames (builtins.readDir path)
      )
    else if pathType == "unknown" then
      [ ]
    else
      [ path ];

  XDGConfigMutableSymlinksRecursive = builtins.listToAttrs (
    builtins.map (file: {
      name = lib.removePrefix (toString ./.) (toString file);
      value = {
        source = mkMutableSymlink file;
      };
    }) (listFilesRecursive ./.config)
  );
in
{
  programs.zsh.enable = true;
  programs.git = {
    enable = true;
    signing.signByDefault = true;
    signing.format = "ssh";
    signing.key = "~/.ssh/id_ed25519";
    settings = {
      user.name = "Mirza Esaaf Shuja";
      user.email = "mirzaesaaf@gmail.com";
    };
  };

  modules.giantswarm.enable = true;
  modules.hyprland.enable = true;
  programs.dankMaterialShell = {
    enable = true;

    plugins = with pkgs.dmsPlugins; {
      power-usage.enable = true;
      power-usage.src = power-usage;
    };
  };

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
    defaultSettings.communityPlugins = with pkgs.obsidianPlugins; [
      github-embeds
      shiki
    ];

    vaults.tinkering = {
      enable = true;
      target = "Documents/tinkering";
    };
  };

  programs.vscode = {
    enable = true;
    # mutableExtensionsDir = false;

    package = pkgs.vscode.fhsWithPackages (
      pkgs: with pkgs; [
        stdenv.cc.cc.lib
        libuuid
      ]
    );

    profiles.default.extensions =
      # NOTE: Latest version of these extensions are not compatible with the vscode available in nixpkgs
      (with pkgs.vscode-extensions; [
        github.copilot-chat
      ])
      ++ (with pkgs.nix-vscode-extensions.vscode-marketplace; [
        ms-azuretools.vscode-containers
        ms-vscode.vscode-speech
        ms-vscode-remote.remote-containers
        jnoortheen.nix-ide
        christian-kohler.path-intellisense
        mkhl.direnv
        github.copilot
        github.vscode-github-actions
        eamodio.gitlens
        visualstudioexptteam.vscodeintellicode
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
        redhat.java
        vscjava.vscode-maven
        vscjava.vscode-gradle
        vscjava.vscode-java-test
        vscjava.vscode-java-debug
        vscjava.vscode-java-dependency
        haskell.haskell
        justusadam.language-haskell
        tomoki1207.pdf
        hashicorp.hcl
        hashicorp.terraform
        ms-vscode.wordcount
        theqtcompany.qt-core
        theqtcompany.qt-qml
      ]);
  };

  home.packages = with pkgs; [
    wget
    curl

    rclone
    catppuccin

    # Graphical applications
    libreoffice
    google-chrome
    veracrypt
    vlc
    protonplus
    heroic
    lutris
    mongodb-compass
    proton-pass
    drawio
    mailspring
    rocketchat-desktop

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

    azure-cli
    kubelogin
    postman
  ];

  wayland.windowManager.hyprland.extraConfig = ''
    source=hyprland/general.conf
    source=hyprland/env.conf
    source=hyprland/execs.conf
    source=hyprland/keybinds.conf
    source=hyprland/rules.conf
    source=hyprland/permissions.conf
  ''; # The actual configs are here, which is a mutable symlink to allow live changes
  xdg.configFile = XDGConfigMutableSymlinksRecursive; # All config files will be writable
  home.file.".vscode/argv.json".source = mkMutableSymlink ./.vscode/argv.json;

  modules.kubernetes.enable = true;
  modules.podman.enable = true;
  modules.podman.tui = true;
  modules.vpn.enable = true;
}
