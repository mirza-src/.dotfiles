{
  pkgs,
  inputs,
  ...
}@args:
rec {
  umple-bin = pkgs.callPackage ./umple-bin.nix { };
  microsoft-edge = pkgs.callPackage ./microsoft-edge.nix { };
  quickshell = inputs.quickshell.packages.${pkgs.system}.quickshell;
  quickshell-with-modules = (
    quickshell.withModules (
      with pkgs.qt6;
      [
        qt5compat
        qtpositioning
      ]
    )
  );

  obsidianPlugins = import ./obsidian-plugins args;
}
