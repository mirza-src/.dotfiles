args: {
  # Valid in both NixOS and nix-darwin; included by nixos and darwin below.
  common = import ./common args;
  nixos = import ./nixos args;
  darwin = import ./darwin args;
  home-manager = import ./home-manager args;
}
