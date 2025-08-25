{
  pkgs,
  system,
  quickshell,
  ...
}:
{
  umple-bin = pkgs.callPackage ./umple-bin.nix { };
  microsoft-edge = pkgs.callPackage ./microsoft-edge.nix { };
  quickshell-with-modules = (
    quickshell.packages.${system}.default.withModules (
      with pkgs.qt6;
      [
        qt5compat
        qtpositioning
      ]
    )
  );

  # TODO: Create nested packages overlays like obsidianPlugins.github-embeds
  obsidian-github-embeds = pkgs.callPackage ./obsidian-plugins/github-embeds.nix { };
  obsidian-shiki = pkgs.callPackage ./obsidian-plugins/shiki.nix { };
}
