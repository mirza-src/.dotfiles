{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.gpu-nvidia;
in
{
  imports = [
    # ./gpu.nix
  ];

  options.modules.gpu-nvidia = {
    enable = mkEnableOption "Enable Nvidia GPU Configuration";
  };

  config = mkIf cfg.enable {
    # boot.initrd.kernelModules = [ "nvidia" ];
    services.xserver.videoDrivers = [ "nvidia" ];
    nixpkgs.config.cudaSupport = true;

    environment.systemPackages = with pkgs; [
      nvitop
      cudatoolkit
      cudaPackages.cuda_nvcc
      linuxPackages.nvidia_x11
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
        # HACK: https://github.com/NixOS/nixpkgs/issues/489947
        with config.boot.kernelPackages.nvidiaPackages;
        (
          latest
          // {
            open = latest.open.overrideAttrs (prev: {
              patches = (prev.patches or [ ]) ++ [
                (pkgs.fetchpatch {
                  url = "https://raw.githubusercontent.com/CachyOS/CachyOS-PKGBUILDS/refs/heads/master/nvidia/nvidia-utils/kernel-6.19.patch";
                  hash = "sha256-YuJjSUXE6jYSuZySYGnWSNG5sfVei7vvxDcHx3K+IN4=";
                })
              ];
            });
          }
        );

      dynamicBoost.enable = false;
    };

    hardware.graphics = {
      extraPackages = with pkgs; [ nvidia-vaapi-driver ];
    };

    hardware.nvidia-container-toolkit.enable = true;
  };
}
