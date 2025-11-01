{ ... }:
{
  programs.dankMaterialShell.greeter.configHome = "/home/mirza";

  users.users = {
    mirza = {
      isNormalUser = true;
      description = "Mirza Esaaf Shuja";
      initialPassword = "password"; # Change this on first login
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "podman"
        "input"
        "audio"
        "video"
        "disk"
        "incus-admin"
      ];
    };
  };
}
