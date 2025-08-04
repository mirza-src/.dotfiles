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
  programs.git.enable = true;
  programs.git.userName = "Mirza Esaaf Shuja";
  programs.git.userEmail = "mirzaesaaf@gmail.com";

  modules.hyprland.enable = true;

  home.packages = with pkgs; [
    wget
    curl

    rclone
    catppuccin

    # Graphical applications
    libreoffice
    microsoft-edge
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
    # TODO: Improve vscode extensions management
    (vscode-with-extensions.override {
      vscodeExtensions = (
        with vscode-extensions;
        [
          ms-vscode-remote.remote-containers
          jnoortheen.nix-ide
          christian-kohler.path-intellisense
          mkhl.direnv
          github.copilot
          github.copilot-chat
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
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "wordcount";
            publisher = "ms-vscode";
            version = "0.1.0";
            sha256 = "41be0a5372b436c53b53619666c700e96024e34e916e700ea4822fbc82389a98";
          }
          {
            name = "vscode-containers";
            publisher = "ms-azuretools";
            version = "2.0.1";
            sha256 = "3da223deda3139be6d0976944431842a6db2a8a7f631cbaa608ecd1aa4d0122c";
          }
          {
            name = "qt-core";
            publisher = "TheQtCompany";
            version = "1.6.0";
            sha256 = "9a2d9cb31ee9bbf0c97ade900ff9ede7f835aad520fea234cb4192612561eb37";
          }
          {
            name = "qt-qml";
            publisher = "TheQtCompany";
            version = "1.7.0";
            sha256 = "4237ef648704e0b70953ddd889837fcf290496e1ed47bcd53b06223cbd24f9c4";
          }
          {
            name = "umple";
            publisher = "digized";
            version = "1.2.1";
            sha256 = "041de915df780688d4b83cc3fa0b979281e14d606b8f099f2401e33a0a5d3a2c";
          }
        ]
      );
    })

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
    umple-bin
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
    source = ./hyprland-custom.conf
  ''; # The actual config is here, which is a mutable symlink to allow live changes
  xdg.configFile = XDGConfigMutableSymlinksRecursive; # All config files will be writable

  modules.kubernetes.enable = true;
  modules.podman.enable = true;
  services.podman.containers = {
    umple = {
      image = "umple/umpleonline";
      ports = [ "8000:8000" ];
      volumes = [
        "umple:/var/www/ump"
      ];
    };
  };
}
