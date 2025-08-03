{ pkgs, ... }:
{
  programs.git.enable = true;
  programs.git.userName = "Mirza Esaaf Shuja";
  programs.git.userEmail = "mirzaesaaf@gmail.com";

  modules.hyprland.enable = true;
  wayland.windowManager.hyprland.extraConfig = builtins.readFile ./.config/hypr/hyprland.conf; # Not needed just avoiding hoome-manager warning

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
    (vscode-with-extensions.override {
      vscodeExtensions = (
        with vscode-extensions;
        [
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
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "vscode-containers";
            publisher = "ms-azuretools";
            version = "2.0.1";
            sha256 = "3da223deda3139be6d0976944431842a6db2a8a7f631cbaa608ecd1aa4d0122c";
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
    ghc
    haskell-language-server
    cabal-install
    nodejs
    python3
    jdk
    umple-bin
    glpk
  ];

  home.file.".config/Code/User/settings.json".text = builtins.readFile ../../.vscode/settings.json;
  home.file.".config" = {
    source = ./.config;
    target = ".config";
    recursive = true;
  };

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
