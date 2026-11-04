{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./programs.nix
    ./users.nix

    ./hardware-configuration.nix

    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia

    inputs.mangowm.nixosModules.mango
    inputs.dank-greeter.nixosModules.default
  ];

  boot.kernelParams = [
    "kvm.enable_virt_at_load=0"
    "nvme_core.default_ps_max_latency_us=0"
  ];
  services.printing.enable = true;
  services.fwupd.enable = true;
  networking.wireguard.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false; # see WIFI_PWR_ON_BAT in power.nix
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openconnect
  ];

  modules.defaults.enable = true;
  modules.shell.enable = true;
  modules.nix.enable = true;
  services.rke2.enable = false;
  modules.k3s.enable = false;

  modules.locale = "en_US.UTF-8";
  services.xserver.xkb.layout = "us";
  time.timeZone = null;
  time.hardwareClockInLocalTime = true;
  services.automatic-timezoned.enable = true;

  modules.audio.enable = true;
  modules.bluetooth.enable = true;
  modules.asus.enable = true;
  modules.gpu.amd.enable = true;
  modules.gpu.nvidia.enable = true;
  modules.gpu.nvidia-prime.enable = true;
  modules.gpu.nvidia-prime.amdBusId = "PCI:101:0:0";
  modules.gpu.nvidia-prime.nvidiaBusId = "PCI:100:0:0";
  modules.gaming.enable = true;
  modules.power.enable = true;
  modules.local-ai.enable = true;

  modules.silent-boot.enable = true;
  # modules.secure-boot.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  programs.mango.enable = true;
  xdg.portal = {
    xdgOpenUsePortal = true;
    # Screen-share picker via the DMS screencastPicker plugin.
    wlr.settings.screencast = {
      chooser_type = "dmenu"; # only mode that offers windows as well as monitors
      chooser_cmd = "${
        inputs.dms-plugin-registry.packages.${pkgs.stdenv.system}.screencastPicker
      }/bin/screencast-picker";
    };
  };
  # Picker talks to DMS over IPC and grabs window thumbnails with grim.
  systemd.user.services.xdg-desktop-portal-wlr.path = [
    pkgs.grim
    inputs.dank-material-shell.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell
  ];
  programs.dms-greeter = {
    enable = true;
    compositor.name = "mango";
  };
  environment.sessionVariables = {
    UWSM_SILENT_START = "1";
  };
  programs.uwsm = {
    enable = true;
    waylandCompositors = {
      mango = {
        prettyName = "Mango";
        comment = "Mango Compositor managed by UWSM";
        binPath = "${pkgs.mango}/bin/mango";
      };
    };
  };
  security.polkit.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  virtualisation.docker.enable = true;
  networking.nftables.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.incus.ui.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  virtualisation.spiceUSBRedirection.enable = true;

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true;
      UseDns = true;
      X11Forwarding = true;
      PermitRootLogin = "yes";
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.allowedUDPPorts = [ 22 ];

  networking.wg-quick.interfaces.hs-fulda = {
    autostart = false;
    address = [
      "10.248.0.9/19"
      "2001:638:301:f820::9/64"
    ];
    dns = [
      "10.0.0.53"
      "2001:638:301::53"
    ];
    privateKeyFile = "/home/mirza/.wg/hs-fulda.key";
    peers = [
      {
        endpoint = "eduvpn01.rz.hs-fulda.de:443";
        publicKey = "E9rVjRfxl5F6amOjc5FBQ7+1minLp60LetMF/y2N3wE=";
        allowedIPs = [
          "0.0.0.0/0"
          "::/0"
        ];
      }
    ];
  };

  # services.mango-headless.enable = true;
  # services.mango-headless.wlr-render-device = "/dev/dri/renderD129"; # AMD GPU render node
  systemd.user.services.mango-headless.bindsTo = [ "sunshine.service" ];
  systemd.user.services.mango-headless.before = [ "sunshine.service" ];
  systemd.user.services.sunshine.requires = [ "mango-headless.service" ];
  systemd.user.services.sunshine.after = [ "mango-headless.service" ];
  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      adapter_name = "/dev/dri/renderD129";
      encoder = "vaapi";
    };
    applications = {
      apps = [
        {
          name = "Steam";
          detached = [
            "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture"
          ];
          prep-cmd = [
            # {
            #   do = "mmsg dispatch create_virtual_output,HEADLESS-1";
            #   undo = "mmsg dispatch destroy_virtual_output,HEADLESS-1";
            # }
            # {
            #   do = "wlr-randr --output HEADLESS-1 --cusotm-mode \${SUNSHINE_CLIENT_WIDTH}x\${SUNSHINE_CLIENT_HEIGHT}@\${SUNSHINE_CLIENT_FPS}Hz";
            # }
          ];
        }
      ];
    };
  };
  systemd.user.services.sunshine.environment.WAYLAND_DISPLAY =
    config.services.mango-headless.wayland-display;
  systemd.user.services.sunshine.environment.MANGO_INSTANCE_SIGNATURE =
    config.services.mango-headless.socket;
  systemd.user.services.sunshine.environment.XDG_SESSION_TYPE = "wayland";
  systemd.user.services.sunshine.environment.XDG_CURRENT_DESKTOP = "mango";
}
