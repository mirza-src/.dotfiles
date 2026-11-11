# NixOS half of modules.onepassword (declared in ../common/onepassword.nix):
# let the primary user unlock 1Password with system authentication.
{ lib, config, ... }:
{
  config = lib.mkIf config.modules.onepassword.enable {
    programs._1password-gui.polkitPolicyOwners = [ config.modules.defaults.primaryUser ];
  };
}
