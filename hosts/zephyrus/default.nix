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

  modules.silent-boot.enable = true;
  # modules.secure-boot.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  programs.mango.enable = true;
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

  services.sway-headless.enable = true;
  services.sunshine = {
    enable = false;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    package = pkgs.sunshine.override {
      cudaSupport = true;
      cudaPackages = pkgs.cudaPackages;
    };
    settings = {
      global_prep_cmd = builtins.toJSON [
        {
          do = "sh -c \"SWAYSOCK=$XDG_RUNTIME_DIR/${config.services.sway-headless.socket} swaymsg output HEADLESS-1 mode \${SUNSHINE_CLIENT_WIDTH}x\${SUNSHINE_CLIENT_HEIGHT}@\${SUNSHINE_CLIENT_FPS}Hz\"";
          undo = "sh -c \"SWAYSOCK=$XDG_RUNTIME_DIR/${config.services.sway-headless.socket} swaymsg output HEADLESS-1 mode ${config.services.sway-headless.mode}\"";
        }
      ];
    };
  };
  systemd.user.services.sunshine.environment.WAYLAND_DISPLAY =
    config.services.sway-headless.wayland-display;
}
