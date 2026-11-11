# macOS-only home-manager config (standalone home-manager now; nix-darwin
# can import this user's config later). Everything cross-platform is in
# ./default.nix; this holds macOS builds and macOS paths.
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.packages = with pkgs; [
    # macOS builds of apps that are Linux-built in linux.nix
    libreoffice-bin
    vlc-bin
    ghostty-bin
  ];
  # Fonts come from the host on both platforms (modules.fonts).

  # VS Code keeps its settings under ~/Library/Application Support on macOS;
  # same files as Linux's ~/.config/Code, linked writable.
  home.file = {
    "Library/Application Support/Code/User/settings.json".source =
      config.lib.dotfiles.mkMutableSymlink ./.config/Code/User/settings.json;
    "Library/Application Support/Code - Insiders/User/settings.json".source =
      config.lib.dotfiles.mkMutableSymlink
        (./.config + "/Code - Insiders/User/settings.json");
  };

  # Not available on macOS: veracrypt, protonplus, rocketchat-desktop,
  # Dolphin/Ark, i2c-tools, eduvpn-client.
}
