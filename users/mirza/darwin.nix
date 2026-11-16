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

  targets.darwin.defaults."com.apple.dock".persistent-apps =
    map (app: "${config.home.homeDirectory}/Applications/Home Manager Apps/${app}.app")
      [
        "Firefox"
        "Zed"
        "kitty"
        "Slack"
      ];

  # The Dock only rereads its settings on restart: restart it when the app
  # list changed since the last switch.
  home.activation.restartDock =
    let
      apps = builtins.hashString "sha256" (
        builtins.toJSON config.targets.darwin.defaults."com.apple.dock".persistent-apps
      );
    in
    lib.hm.dag.entryAfter [ "setDarwinDefaults" ] ''
      dockStamp="${config.xdg.stateHome}/home-manager/dock-apps"
      if [[ ! -v DRY_RUN ]] && [[ "$(cat "$dockStamp" 2>/dev/null)" != "${apps}" ]]; then
        /usr/bin/killall Dock || true
        mkdir -p "$(dirname "$dockStamp")"
        echo "${apps}" > "$dockStamp"
      fi
    '';

  # Not available on macOS: veracrypt, protonplus, rocketchat-desktop,
  # Dolphin/Ark, i2c-tools, eduvpn-client.
}
