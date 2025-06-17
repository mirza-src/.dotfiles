{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.modules.k3s;
in
{
  options.modules.k3s = {
    enable = mkEnableOption "Enable K3s Kubernetes cluster";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kubectl
      kubectx
      helm
    ];

    services.k3s = {
      enable = true;
      role = "server";
      clusterInit = true;
      # token = "<randomized common secret>";
    };
    systemd.services.k3s.wantedBy = lib.mkForce [ ];
    networking.firewall.allowedTCPPorts = [
      6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
      2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      10250 # k3s, kubelet: required for communication with the kubelet (e.g. for metrics-server)
    ];
    networking.firewall.allowedUDPPorts = [
      8472 # k3s, flannel: required if using multi-node for inter-node networking
    ];
  };
}
