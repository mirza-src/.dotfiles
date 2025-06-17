{ ... }:
{
  users.users = {
    mirza = {
      isNormalUser = true;
      description = "Mirza Esaaf Shuja";
      extraGroups = [
        "networkmanager"
        "wheel"
        "docker"
        "podman"
        "input"
        "video"
      ];
    };
  };
}
