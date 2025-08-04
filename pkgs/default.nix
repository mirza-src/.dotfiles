{
  pkgs,
  system,
  quickshell,
  ...
}:
{
  umple-bin = pkgs.callPackage ./umple-bin.nix { };
  microsoft-edge = pkgs.callPackage ./microsoft-edge.nix { };
  quickshell = quickshell.packages.${system}.default;
  quickshell-with-modules = (
    pkgs.quickshell.withModules (
      with pkgs.qt6;
      [
        qt5compat
        qtpositioning
      ]
    )
  );
}
