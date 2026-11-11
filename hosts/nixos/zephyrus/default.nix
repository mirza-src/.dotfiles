{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ./programs.nix
    ./users.nix
    ./sunshine.nix

    ./hardware-configuration.nix

    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia

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

  # NixOS release of the first install; don't bump (see `man configuration.nix`).
  system.stateVersion = "25.05";

  modules.defaults = {
    enable = true;
    primaryUser = "mirza";
    displayName = "Zephyrus G14";
  };
  modules.shell.enable = true;
  modules.nix.enable = true;
  services.rke2.enable = false;
  modules.k3s.enable = false;

  modules.locale = "en_US.UTF-8";
  services.xserver.xkb.layout = "us";
  time.timeZone = null;
  services.automatic-timezoned.enable = true;

  modules.audio.enable = true;
  modules.bluetooth.enable = true;
  modules.asus.enable = true;
  modules.gpu.amd.enable = true;
  modules.gpu.nvidia.enable = true;
  modules.gpu.nvidia-prime.enable = true;
  modules.gpu.nvidia-prime.amdBusId = "PCI:101:0:0";
  modules.gpu.nvidia-prime.nvidiaBusId = "PCI:100:0:0";
  # Experimental: live panel switching between iGPU and dGPU (cardwire
  # "ultimate" mode), see modules/nixos/gpu/dynamic-mux.nix.
  modules.gpu.dynamic-mux.enable = true;
  modules.gaming.enable = true;
  modules.power.enable = true;
  modules.local-ai.enable = true;

  modules.silent-boot.enable = true;
  # modules.secure-boot.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  # Default desktop: mango + DankMaterialShell + dms-greeter, DMS plugins and
  # their system-level backends (modules/nixos/desktop.nix).
  modules.desktop.enable = true;
  # Face authentication (Gaze): sudo, polkit and the DMS lock screen, password
  # stays as fallback. The RGB and IR cameras share one USB id; for the IR
  # camera Gaze picks the mono (GREY) node of that device.
  modules.face-auth = {
    enable = true;
    irCamera = "usb:3277:0060";
    greeter = true; # dms-greeter face login + gnome-keyring unlock (run `gaze keyring` once)
  };

  virtualisation.docker.enable = true;
  networking.nftables.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.incus.ui.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  virtualisation.spiceUSBRedirection.enable = true;

  # Key-only SSH (openFirewall opens TCP 22). Add public keys via
  # users.users.<name>.openssh.authorizedKeys.keys or ~/.ssh/authorized_keys.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

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

  services.avahi.enable = true;
  # Forcefully nullify the legacy options to stop upstream modules from triggering the warnings
  services.avahi.publish.enable = null;
  services.avahi.publish.userServices = null;
  services.avahi.settings = {
    # Explicitly declare settings using the modern syntax to override the legacy defaults
    publish = {
      disable-publishing = false;
      publish-addresses = true;
      disable-user-service-publishing = false;
    };
  };
}
