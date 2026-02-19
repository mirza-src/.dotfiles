{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with lib;
let
  cfg = config.modules.slurm-microvm-hpc;
in
{
  imports = [
    inputs.microvm.nixosModules.host
  ];

  options.modules.slurm-microvm-hpc = {
    enable = mkEnableOption "Enable Slurm HPC";

    hypervisor = mkOption {
      type = types.enum inputs.microvm.lib.hypervisors;
      default = "qemu";
      description = ''
        Which hypervisor to use for this MicroVM

        Choose one of: ${lib.concatStringsSep ", " inputs.microvm.lib.hypervisors}
      '';
    };

    numVMs = mkOption {
      type = types.int;
      default = 3;
      description = "Number of MicroVMs to create for the Slurm HPC cluster.";
    };

    bridgeInterface = mkOption {
      type = types.str;
      default = "virbr0";
      description = "The bridge interface to attach MicroVMs to.";
    };
  };

  config = mkIf cfg.enable (
    let
      macAddressFromString =
        str:
        let
          hash = builtins.hashString "sha256" str;
          c = off: builtins.substring off 2 hash;
        in
        "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

      vms = lib.genList (i: "microvm${toString i}") cfg.numVMs;

      vmMacAddresses = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = macAddressFromString name;
        }) vms
      );

      vmIPv4Addresses = builtins.listToAttrs (
        lib.imap0 (i: name: {
          inherit name;
          value = "10.0.0.${toString (i + 2)}";
        }) vms
      );

      extraHosts = lib.concatMapStrings (name: ''
        ${vmIPv4Addresses.${name}} ${name}
      '') vms;
    in
    {
      microvm.vms = builtins.mapAttrs (name: mac: {
        autostart = true;
        restartIfChanged = true;

        config = {
          system.stateVersion = lib.trivial.release;
          networking.hostName = name;

          microvm = {
            hypervisor = cfg.hypervisor;
            interfaces = [
              {
                inherit mac;
                type = "tap";
                id = name;
              }
            ];
            shares = [
              {
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                tag = "ro-store";
                proto = "virtiofs";
              }
              {
                source = "/etc/munge";
                mountPoint = "/etc/munge";
                tag = "munge-key";
                proto = "virtiofs";
              }
            ];
            writableStoreOverlay = "/nix/.rw-store";
          };

          # Just use 99-ethernet-default-dhcp.network
          systemd.network.enable = true;
          # system.nssDatabases.hosts = lib.mkForce [ "mymachines resolve files myhostname dns" ];
          networking.firewall.allowedTCPPorts = [
            6818 # slurmd
          ];
          networking.firewall.allowedUDPPorts = [
            5353 # mDNS
            5355 # LLMNR
          ];
          networking.hosts = {
            "10.0.0.1" = [ config.networking.hostName ];
          };
          # networking.extraHosts = extraHosts;

          users.users.root.password = "toor";
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          environment.systemPackages = with pkgs; [
            # Core utilities
            git
            wget
            curl
            jq
            yq

            # Device management
            fwup
            lshw
            pciutils
            usbutils

            # Networking tools
            inetutils
            nettools
            dnsutils
            tcpdump
          ];

          services.slurm = {
            client.enable = true;
          };
          systemd.services.slurmd.serviceConfig.ExecStart =
            lib.mkForce "${pkgs.slurm}/bin/slurmd --conf-server ${config.networking.hostName}";
          systemd.services.munged.serviceConfig = {
            User = lib.mkForce "root";
            Group = lib.mkForce "root";
          };
        };
      }) vmMacAddresses;

      # Disable systemd-resolved DNS stub listener to avoid port conflicts with dnsmasq
      # services.resolved.extraConfig = ''
      #   DNSStubListener=no
      # '';
      # Enable dnsmasq to provide DNS for the microVM bridge
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = cfg.bridgeInterface;
          bind-interfaces = true;
          no-resolv = true;
          server = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          # dhcp-range = "10.0.0.2,10.0.0.254,12h";
        };
      };

      systemd.network = {
        enable = true;
        netdevs.virbr0.netdevConfig = {
          Kind = "bridge";
          Name = cfg.bridgeInterface;
        };
        networks.virbr0 = {
          matchConfig.Name = cfg.bridgeInterface;

          addresses = [
            {
              Address = "10.0.0.1/24";
            }
            {
              Address = "fd12:3456:789a::1/64";
            }
          ];
          # Use `networkctl status virbr0` to see leases.
          networkConfig = {
            DHCPServer = true;
            IPv6SendRA = true;
          };
          ipv6Prefixes = [
            {
              Prefix = "fd12:3456:789a::/64";
            }
          ];
          dhcpServerConfig = {
            PersistLeases = "no";
            DefaultLeaseTimeSec = "5m";
          };
          # Let DHCP assign a statically known address to the VMs
          dhcpServerStaticLeases = lib.imap0 (i: vm: {
            MACAddress = vmMacAddresses.${vm};
            Address = vmIPv4Addresses.${vm};
          }) vms;
        };
        networks.microvm-eth0 = {
          matchConfig.Name = "microvm*";
          networkConfig.Bridge = cfg.bridgeInterface;
        };
      };

      # networking.extraHosts = extraHosts;
      networking.nameservers = [ "10.0.0.1" ];
      networking.networkmanager.dns = "systemd-resolved";
      networking.networkmanager.insertNameservers = config.networking.nameservers;
      # Allow DHCP server
      networking.firewall.allowedUDPPorts = [
        67 # DHCP Server
        5353 # mDNS
        5355 # LLMNR
      ];
      networking.firewall.allowedTCPPorts = [
        6817 # slurmctld
      ];

      networking.firewall.allowedTCPPortRanges = [
        # Slurm srun port range
        {
          from = 60001;
          to = 63000;
        }
      ];

      # Allow Internet access
      networking.nat = {
        enable = true;
        enableIPv6 = true;
        internalInterfaces = [ cfg.bridgeInterface ];
      };
      # system.nssDatabases.hosts = lib.mkForce [ "mymachines resolve files myhostname dns" ];

      services.slurm = {
        server.enable = true;
        extraConfig = ''
          SlurmctldHost=${config.networking.hostName}
          SlurmctldParameters=enable_configless
          SrunPortRange=60001-63000
        '';
        nodeName = [
          "microvm[0-${toString (cfg.numVMs - 1)}]"
        ];
        partitionName = [
          "ALL Nodes=ALL Default=YES MaxTime=INFINITE State=UP"
        ];
      };
      systemd.services.slurmctld.after = [
        "dnsmasq.service"
        "systemd-resolved.service"
      ]
      ++ (map (vm: "microvm@${vm}.service") vms);
      systemd.services.munged.serviceConfig = {
        User = lib.mkForce "root";
        Group = lib.mkForce "root";
      };
    }
  );
}
