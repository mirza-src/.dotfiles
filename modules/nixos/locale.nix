{ lib, config, ... }:
with lib;
let
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
    i18n.extraLocaleSettings = {
      LC_ADDRESS = cfg;
      LC_IDENTIFICATION = cfg;
      LC_MEASUREMENT = cfg;
      LC_MONETARY = cfg;
      LC_NAME = cfg;
      LC_NUMERIC = cfg;
      LC_PAPER = cfg;
      LC_TELEPHONE = cfg;
      LC_TIME = cfg;
    };
  };
}
