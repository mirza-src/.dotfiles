{ pkgs, ... }: {
  programs.firefox.enable = false;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraPkgs = pkgs:
        with pkgs; [
          primus
          bumblebee
          glxinfo
        ];
    };
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };
  programs.gamemode.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = (
    with pkgs;
      [
        git
        gh
        vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
        wget
        curl
        home-manager
        lshw
        pciutils
        usbutils
        linux-firmware
        powertop
        nvitop
        nvtopPackages.amd
        # nvtopPackages.nvidia
        gpustat
        gobject-introspection
        vulnix
        statix
        deadnix
        nil
        nixd
        alejandra
        nixfmt-rfc-style
        rclone
        direnv
        devenv
        (vscode-with-extensions.override {
          vscodeExtensions = (
            with vscode-extensions;
              [
                jnoortheen.nix-ide
                christian-kohler.path-intellisense
                mkhl.direnv
                github.copilot
                github.vscode-github-actions
                eamodio.gitlens
                ms-azuretools.vscode-docker
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
                vscjava.vscode-java-pack
              ]
              ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
                {
                  name = "Umple";
                  publisher = "digized";
                  version = "1.2.1";
                  sha256 = "041de915df780688d4b83cc3fa0b979281e14d606b8f099f2401e33a0a5d3a2c";
                }
              ]
          );
        })
        microsoft-edge
        google-chrome
        # asusctl
        # supergfxctl
        lact
        yaru-theme
        gthumb
        gnome-tweaks
        vkd3d
        mesa
        gnome-power-manager
      ]
      ++ (with gnomeExtensions; [
        appindicator
        battery-health-charging
        freon
        settingscenter
        zen
        containers
      ])
      ++ [
        podman-compose
        podman-tui
        podman-desktop
        kubectl
      ]
  );

  services.switcherooControl.enable = true;
  services.asusd.enable = true;
  services.supergfxd.enable = true;

  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  hardware.nvidia-container-toolkit.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mirza = {
    isNormalUser = true;
    description = "Mirza Esaaf Shuja";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      gobject-introspection
      haskell.compiler.ghc984
      libreoffice
      umple-bin
      nodejs
      python3
      jdk
      ant
      veracrypt
      vlc
      protonplus
      heroic
      lutris
    ];
  };
}
