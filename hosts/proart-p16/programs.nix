{ pkgs, lib, ... }:
{
  fonts.packages =
    with pkgs;
    [
      font-awesome
      noto-fonts-emoji
      meslo-lgs-nf
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  programs.git.enable = true;
  programs.git.lfs.enable = true;
  programs.git.lfs.enablePureSSHTransfer = true;
  programs.git-worktree-switcher.enable = true;
  programs.vim.enable = true;
  programs.firefox.enable = true;

  programs.anime-games-launcher.enable = false;
  programs.anime-game-launcher.enable = true;
  programs.honkers-launcher.enable = true;
  programs.honkers-railway-launcher.enable = true;
  programs.wavey-launcher.enable = true;
  programs.sleepy-launcher.enable = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    localhost = {
      locations."/" = {
        proxyPass = "http://localhost:8000";
      };
      locations."=/" = {
        proxyPass = "http://localhost:8000/umple.php";
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Core utilities
    wget
    curl
    inetutils

    # Device management
    fwup
    lshw
    pciutils
    usbutils

    # Development tools
    gcc
    libgcc
    gnumake

    # Disk management
    libbde
    cryptsetup
    dislocker
    gparted
  ];
}
