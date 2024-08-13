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
    nil
    nixd
    nixpkgs-fmt

    colima
    docker
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Necessary settings for nix-darwin.
  nix = {
    # package = pkgs.nixVersions.latest;
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
      # extra-platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    };
    # Enable linux-builder for remote linux builds.
    linux-builder = {
      enable = true;
      ephemeral = true;
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
