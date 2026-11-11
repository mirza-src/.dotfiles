# System modules valid in both NixOS and nix-darwin: they may only use options
# that exist in both (nix.*, nixpkgs.*, environment.systemPackages,
# networking.hostName, ...). Platform-only modules live in ../nixos and
# ../darwin, and both include this set. User-level config that should
# be identical everywhere belongs in ../home-manager instead.
{ self, ... }: self.lib.createModuleEntryPoint ./.
