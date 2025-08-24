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
}
