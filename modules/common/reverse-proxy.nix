# One entry point for this machine's web services: Caddy on ports 80/443,
# routing by path to services that only listen on localhost. The platform
# halves (../nixos/reverse-proxy.nix, ../darwin/reverse-proxy.nix) run it.
#
#   http://<host>/<route>/                  LAN and tailnet
#   https://<host>.<tailnet>/<route>/       tailnet, with a real certificate
#                                           (modules.tailscale.domain)
#
# A new service only needs a route:
#   modules.reverse-proxy.routes."/grafana".to = "127.0.0.1:3000";
# By default the prefix is stripped, so the service must work under a
# sub-path (most have a "base URL" setting); "/" is for one that can't.
{ config, lib, ... }:
let
  inherit (lib)
    concatStrings
    mapAttrsToList
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.modules.reverse-proxy;
  ts = config.modules.tailscale;

  route =
    path: r:
    if path == "/" then
      ''
        handle {
          reverse_proxy ${r.to}
        }
      ''
    else
      ''
        redir ${path} ${path}/
        ${if r.strip then "handle_path" else "handle"} ${path}/* {
          reverse_proxy ${r.to}
        }
      '';

  routes = ''
    ${lib.optionalString (!cfg.lanAccess) ''
      # Tailnet only: the firewall enforces it on NixOS, this everywhere
      # (macOS has no firewall rules here).
      @outside not remote_ip ${cfg.privateRanges}
      handle @outside {
        abort
      }
    ''}
    ${concatStrings (mapAttrsToList route (removeAttrs cfg.routes [ "/" ]))}
    ${cfg.extraConfig}
    ${
      if cfg.routes ? "/" then
        route "/" cfg.routes."/"
      else
        ''
          handle {
            respond "Nothing here" 404
          }
        ''
    }
  '';

  caddyfile = ''
    (routes) {
    ${routes}
    }

    # Any name or address, plain HTTP: LAN devices can't validate a
    # certificate for an IP or a .local name.
    http:// {
      import routes
    }
  ''
  + lib.optionalString (ts.enable && ts.domain != null) ''

    # Certificate from tailscaled (Caddy asks it for *.ts.net names).
    https://${config.networking.hostName}.${ts.domain} {
      import routes
    }
  '';
in
{
  options.modules.reverse-proxy = {
    enable = mkEnableOption "Caddy on ports 80/443 in front of this machine's web services";

    lanAccess = mkEnableOption ''
      the services on every network (LAN devices without Tailscale too).
      Nothing asks for a password, so on public Wi-Fi anyone there can use
      them. Off: only this machine and the tailnet (privateRanges)
    '';

    privateRanges = mkOption {
      type = types.str;
      readOnly = true;
      default = "127.0.0.1/8 ::1 100.64.0.0/10 fd7a:115c:a1e0::/48";
      description = "This machine and the tailnet's addresses, as for Caddy's remote_ip.";
    };

    routes = mkOption {
      default = { };
      description = "Path prefix (\"/name\", or \"/\" for the rest) -> service.";
      type = types.attrsOf (
        types.submodule {
          options = {
            to = mkOption {
              type = types.str;
              example = "127.0.0.1:3000";
              description = "Upstream address(es), as for Caddy's reverse_proxy.";
            };
            strip = mkOption {
              type = types.bool;
              default = true;
              description = "Strip the prefix before passing the request on.";
            };
          };
        }
      );
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Further Caddy directives inside the site, for routes that need more than a proxy.";
    };

    caddyfile = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      default = caddyfile;
    };
  };
}
