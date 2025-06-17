{ callPackage, ... }:
{
  umple-bin = callPackage ./umple-bin.nix { };
  microsoft-edge = callPackage ./microsoft-edge.nix { };
}
