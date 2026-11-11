# MacBook Pro (14", M1 Pro, 2021), nix-darwin with Lix.
#
# First-time setup:
#   1. Install Lix:
#        curl -sSf -L https://install.lix.systems/lix | sh -s -- install
#   2. Clone this repo to ~/.dotfiles (git comes with nix shell if the Xcode
#      command line tools aren't installed):
#        nix shell nixpkgs#git -c git clone <repo> ~/.dotfiles
#   3. Let nix-darwin take over the files the installer created:
#        sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
#      (nix-darwin names any other file it refuses to overwrite, e.g.
#      /etc/zshrc; move those aside the same way.)
#   4. First switch (sets the hostname, so later switches find this config):
#        sudo nix --extra-experimental-features 'nix-command flakes' \
#          run nix-darwin#darwin-rebuild -- switch --flake ~/.dotfiles#macbook-pro
#   5. Home: nh home switch (and from then on: nh darwin switch).
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin release of the first install; see `darwin-rebuild changelog`
  # before changing.
  system.stateVersion = 6;

  modules.defaults = {
    enable = true;
    primaryUser = "mirza";
    displayName = "MacBook Pro M1";
  };
  modules.shell.enable = true;
  modules.nix.enable = true;
  modules.fonts.enable = true;
  modules.onepassword.enable = true;

  modules.hs-fulda-vpn = {
    enable = true;
    address = [
      "10.248.0.136/19"
      "2001:638:301:f820::88/64"
    ];
    mtu = 1392;
  };
}
