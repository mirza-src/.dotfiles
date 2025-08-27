{ pkgs, ... }:
{
  github-embeds = pkgs.callPackage ./github-embeds.nix { };
  shiki = pkgs.callPackage ./shiki.nix { };
}
