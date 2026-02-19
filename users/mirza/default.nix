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
  imports = [
    inputs.niri.homeModules.niri
    inputs.danksearch.homeModules.dsearch
    inputs.dms-plugin-registry.modules.default
    inputs.dank-material-shell.homeModules.niri
  ];

  programs.home-manager.enable = true;
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

  services.ssh-agent.enable = true;
  programs.ssh-agent-switch = {
    enable = true;
    defaultAgent = "bitwarden";
    agents.local = "$XDG_RUNTIME_DIR/${config.services.ssh-agent.socket}";
    agents.bitwarden = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
  };

  programs.firefox.enable = true;
  programs.firefox.package = pkgs.wrapFirefox (pkgs.firefox-unwrapped.override {
    pipewireSupport = true;
  }) { };

  modules.giantswarm.enable = true;
  modules.hyprland.enable = true;
  programs.dsearch.enable = true;
  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true; # Systemd service for auto-start
      restartIfChanged = true; # Auto-restart dms.service when dank-material-shell changes
    };
    niri.enableKeybinds = false;
    niri.includes.enable = false;
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
    defaultSettings.communityPlugins = with pkgs.obsidian-plugins; [
      github-embeds
      shiki
    ];

    vaults.tinkering = {
      enable = true;
      target = "Documents/tinkering";
    };
  };
  home.activation.createObsidianDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.xdg.configHome}/obsidian
  '';

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
    xwayland-satellite

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

    (azure-cli.withExtensions [ azure-cli.extensions.ssh ])
    kubelogin
    postman
    kitty
    vagrant
    ansible
    slack
  ];

  xdg.configFile = XDGConfigMutableSymlinksRecursive; # All config files will be writable
  home.file.".vscode/argv.json".source = mkMutableSymlink ./.vscode/argv.json;
  home.file.".vscode-insiders/argv.json".source = mkMutableSymlink ./.vscode/argv.json;
  home.shellAliases.code = "code-insiders";

  modules.kubernetes.enable = true;
  modules.vpn.enable = true;
}
