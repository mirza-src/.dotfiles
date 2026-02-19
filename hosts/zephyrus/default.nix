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
  ];

  boot.kernelParams = [ "kvm.enable_virt_at_load=0" ];
  services.printing.enable = true;
  services.fwupd.enable = true;
  networking.wireguard.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openconnect
  ];

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
  modules.gpu.enable = true;
  modules.gpu-amd.enable = true;
  modules.gpu-nvidia.enable = true;
  hardware.nvidia.prime.amdgpuBusId = "PCI:101:0:0";
  # hardware.nvidia.prime.nvidiaBusId = "PCI:100:0:0";
  modules.nvidia-prime.enable = false;
  # modules.nvidia-prime.nvidiaBusId = "PCI:100:0:0";
  # modules.nvidia-prime.amdBusId = "PCI:101:0:0";
  # hardware.nvidia.primeBatterySaverSpecialisation = true;
  modules.gaming.enable = true;
  modules.power.enable = true;
  services.system76-scheduler.enable = true;
  services.system76-scheduler.useStockConfig = true;

  modules.silent-boot.enable = true;
  # modules.secure-boot.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.xserver.enable = true;
  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
  };

  modules.gnome.enable = false;
  programs.hyprland.enable = true;
  programs.uwsm.enable = true;
  programs.niri.enable = true;
  services.gnome.gnome-keyring.enable = false;

  virtualisation.docker.enable = true;
  networking.nftables.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.incus.enable = true;
  virtualisation.incus.ui.enable = true;
  networking.firewall.trustedInterfaces = [ "incusbr0" ];
  virtualisation.spiceUSBRedirection.enable = true;

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
}
