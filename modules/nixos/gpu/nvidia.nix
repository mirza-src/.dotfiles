{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.gpu.nvidia;
  nvidiaVulkanIcd = "${config.hardware.nvidia.package}/share/vulkan/icd.d/nvidia_icd.json";
in
{
  imports = [
    ./gpu.nix
  ];

  options.modules.gpu.nvidia = {
    enable = mkEnableOption "Enable Nvidia GPU Configuration";
  };

  config = mkIf cfg.enable {
    modules.gpu.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];
    nixpkgs.config.cudaSupport = true;
    services.supergfxd.enable = false;
    services.cardwired = {
      enable = true;
      settings = {
        battery_auto_switch = true;
        battery_auto_switch_mode = "ultimate";
        experimental_nvidia_block = true;
        external_display_auto_switch = true;
      };
    };

    # The NVIDIA Vulkan ICD (nvidia_icd.json) is missing from the merged
    # /run/opengl-driver env (only Mesa's ICDs end up there), so Vulkan never
    # sees the RTX GPU. That also makes cardwired's discrete-GPU probe fail,
    # which classifies the laptop as "Manual" and disables Integrated/Smart.
    # Register the ICD explicitly for sessions and for the daemon.
    # TODO: find out why the graphics-drivers buildEnv drops nvidia_icd.json
    #   (it's in the nvidia-x11 output) and fix it there instead.
    environment.sessionVariables.VK_ADD_DRIVER_FILES = nvidiaVulkanIcd;
    systemd.services.cardwired.environment.VK_ADD_DRIVER_FILES = nvidiaVulkanIcd;

    environment.systemPackages = with pkgs; [
      nvitop
      cudatoolkit
      cudaPackages.cuda_nvcc
    ];

    hardware.nvidia = {
      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      powerManagement.enable = true;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = config.hardware.nvidia.prime.offload.enable;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      open = true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      # Optionally, you may need to select the appropriate driver version for your specific GPU.
      package =
        let
          base = config.boot.kernelPackages.nvidiaPackages.latest;
        in
        # The NixOS module builds the kernel side from `package.open`.
        base
        // {
          open = base.open.overrideAttrs (old: {
            patches =
              (old.patches or [ ])
              # The probe runs in an "nv-probe-*" kthread that can't see /sys,
              # which silently disables runtime D3 (the dGPU never powers off).
              # TODO: report to NVIDIA/open-gpu-kernel-modules; drop the patch
              #   once a driver release fixes it.
              ++ [ ../../../patches/nvidia-open-rtd3-probe-sysfs.patch ]
              ++ optional config.modules.gpu.dynamic-mux.enable ../../../patches/nvidia-open-dynamic-mux.patch;
          });
        };

      dynamicBoost.enable = false;
    };

    hardware.graphics = {
      extraPackages = with pkgs; [ nvidia-vaapi-driver ];
    };

    hardware.nvidia.primeBatterySaverSpecialisation = true;
    hardware.nvidia-container-toolkit.enable = lib.mkDefault true;
    specialisation = lib.mkIf config.hardware.nvidia.primeBatterySaverSpecialisation {
      battery-saver.configuration = {
        hardware.nvidia-container-toolkit.enable = lib.mkForce false;
      };
    };
    virtualisation.vmVariant = {
      hardware.nvidia-container-toolkit.enable = false;
    };
  };
}
