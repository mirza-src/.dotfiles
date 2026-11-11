{ lib, config, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  cfg = config.modules.locale;
in
{
  options.modules.locale = mkOption {
    type = types.str;
    default = "en_US.UTF-8";
    example = "en_US.UTF-8";
  };

  config = {
    # Select internationalisation properties.
    i18n.defaultLocale = cfg;
  };
}
