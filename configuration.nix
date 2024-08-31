{ inputs, pkgs, username, ... }:
{
  # HACK: https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565974702
  users.users.${username} = {
    home = "/Users/${username}";
  };
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    vim
    git
    delta
    bat
    nil
    nixd
    nixpkgs-fmt

    colima
    docker_26
    dive
    kubectl
    kubernetes-helm
    kubectx

    qbittorrent

    kubelogin
    azure-cli
    azure-storage-azcopy
  ];

  homebrew = {
    enable = true;

    global = {
      autoUpdate = true;
      brewfile = true;
      lockfiles = true;
    };

    onActivation = {
      upgrade = true;
      autoUpdate = true;
      cleanup = "uninstall";
    };

    taps = [
      "mirza-src/tap"
    ];

    brews = [ ];

    casks = [
      "iterm2"
      "openinterminal"
      "google-chrome"
      "amazon-q"
      "visual-studio-code"
      "spotify"
      "lens"
      "pgadmin4"
      "microsoft-teams"
      "microsoft-remote-desktop"
      "microsoft-azure-storage-explorer"
      "webex"
      "whatsapp"
      "ryujinx"
      "vlc"
      "iina"
    ];

    masApps = {
      "Amphetamine" = 937984704;
    };

    whalebrews = [ ];
  };

  security.pam.enableSudoTouchIdAuth = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  # Necessary settings for nix-darwin.
  nix = {
    package = pkgs.nixVersions.latest;
    nixPath = [
      "nixpkgs=${inputs.nixpkgs}"
    ];
    settings = {
      trusted-users = [
        "@admin"
        username
      ];
      extra-trusted-users = [
        "@admin"
        username
      ];
      experimental-features = [ "nix-command" "flakes" ];
      system = "aarch64-darwin";
      extra-platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    };
    # Enable linux-builder for remote linux builds.
    linux-builder = {
      enable = true;
      ephemeral = true;
    };
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      "com.apple.keyboard.fnState" = false;
    };

    CustomUserPreferences = {
      "com.apple.finder" = {
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        ShowMountedServersOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        _FXSortFoldersFirst = true;

        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "Nlsv";
        QuitMenuItem = true;
        ShowPathbar = true;
        FXEnableExtensionChangeWarning = false;
        # When performing a search, search the current folder by default
        FXDefaultSearchScope = "SCcf";
      };
      "com.apple.desktopservices" = {
        # Avoid creating .DS_Store files on network or USB volumes
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        # Check for software updates daily, not just once per week
        ScheduleFrequency = true;
        # Download newly available updates in background
        AutomaticDownload = true;
        # Install System data files & security updates
        CriticalUpdateInstall = true;
      };
    };

    dock = {
      autohide = true;
      show-recents = false;
      persistent-others = [ ];
      persistent-apps = [
        "/Applications/Google Chrome.app"
        "/Applications/Visual Studio Code.app"
        "/Applications/iTerm.app"
        "/Applications/Lens.app"
        "/Applications/Microsoft Teams.app"
      ];
    };

    trackpad = {
      Clicking = true;
      Dragging = true;
      TrackpadThreeFingerDrag = true;
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina

  # Set Git commit hash for darwin-version.
  system.configurationRevision = null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;
}
