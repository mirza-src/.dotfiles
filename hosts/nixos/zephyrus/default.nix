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
    # The kernel refuses to hibernate while any process holds memfd_secret
    # memory, and Bitwarden desktop always does. Off = it falls back to
    # ordinary locked memory.
    "secretmem.enable=0"
    # LZ4 instead of the default LZO for the hibernation image: quicker to
    # read back on resume.
    "hibernate.compressor=lz4"
  ];

  # Swap file for hibernation (32 GB RAM). NixOS creates it on activation,
  # with CoW disabled as btrfs requires. No resume=/resume_offset= needed:
  # systemd stores the location in the HibernateLocation EFI variable and the
  # systemd initrd resumes from it.
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 40 * 1024; # MiB
    }
  ];

  # Power off the ordinary way after writing the hibernation image instead
  # of through the firmware's S4 path, which intermittently leaves this
  # laptop switched on (image written, keyboard backlight lit). Needs
  # patches/nvidia-open-hibernate-shutdown-deadlock.patch, or the NVIDIA
  # driver hangs this path every time.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";
  # Lid close and the suspend key use suspend-then-hibernate
  # (modules/nixos/defaults.nix): hibernate after this long asleep.
  systemd.sleep.settings.Sleep.HibernateDelaySec = "1h";

  # Keep amdgpu out of the initrd (nixos-hardware's common-gpu-amd puts it
  # there). With it in stage 1, resuming from hibernation hangs or comes back
  # with a dead iGPU: 2 of 3 resumes on 7.3.1 ("ring mes_kiq_3.1.0 test failed
  # (-110)") and 2 of 4 on 7.3.4; every resume without it has worked. The
  # boot kernel would otherwise initialise the iGPU and have to quiesce it
  # again before handing over to the hibernated kernel. The splash does not
  # need it: Plymouth draws on the firmware framebuffer (silent-boot.nix).
  hardware.amdgpu.initrd.enable = false;

  services.printing.enable = true;
  services.fwupd.enable = true;
  networking.wireguard.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false; # see WIFI_PWR_ON_BAT in power.nix
  networking.networkmanager.plugins = with pkgs; [
    networkmanager-openconnect
  ];

  # NixOS release of the first install; don't bump (see `man configuration.nix`).
  system.stateVersion = "26.11";

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
  modules.gpu.nvidia.enable = true;
  modules.gpu.nvidia-prime.enable = true;
  modules.gpu.nvidia-prime.amdBusId = "PCI:101:0:0";
  modules.gpu.nvidia-prime.nvidiaBusId = "PCI:100:0:0";
  # Experimental: live panel switching between iGPU and dGPU (cardwire
  # "ultimate" mode), see modules/nixos/gpu/dynamic-mux.nix.
  modules.gpu.dynamic-mux.enable = true;
  modules.onepassword.enable = true;
  modules.gaming.enable = true;
  modules.power.enable = true;
  modules.tailscale.enable = true;
  modules.tailscale.domain = "tailc4d4bc.ts.net"; # https://zephyrus.tailc4d4bc.ts.net
  # http://zephyrus/ (Open WebUI), /llm (local models on whichever machine is
  # free), /comfyui/; see modules/common/local-ai.nix.
  modules.local-ai = {
    enable = true;
    imageGen.enable = true;
    machines = [
      "zephyrus"
      "macbook-pro"
    ];
  };

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

  modules.hs-fulda-vpn = {
    enable = true;
    address = [
      "10.248.0.9/19"
      "2001:638:301:f820::9/64"
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
