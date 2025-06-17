{ self, lib, ... }:
{
  nixos = import ./nixos { inherit self lib; };
  home-manager = import ./home-manager { inherit self lib; };
}
