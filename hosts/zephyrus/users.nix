{ lib, config, ... }:
{
  programs.dms-greeter.configHome = "/home/mirza";
  programs.dms-greeter.compositor.customConfig =
    lib.mkIf (config.programs.dms-greeter.compositor.name == "mango")
      ''
        cursor_size=24
        cursor_theme=Adwaita
        trackpad_natural_scrolling=1
        monitor_rule=name:^eDP-1$,width:2880,height:1800,refresh:60,x:0,y:0,scale:2,rr:0,vrr:0
        monitor_rule=name:^eDP-2$,width:2880,height:1800,refresh:60,x:0,y:0,scale:2,rr:0,vrr:0
      '';

  users.users = {
    mirza = {
      isNormalUser = true;
      description = "Mirza Esaaf Shuja";
      autoSubUidGidRange = true;
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
        "libvirtd"
      ];
    };

    maira = {
      isNormalUser = true;
      description = "Maira Tariq";
      autoSubUidGidRange = true;
      initialPassword = "password"; # Change this on first login
      extraGroups = [
        "networkmanager"
        "docker"
        "podman"
        "input"
        "audio"
        "video"
      ];
    };
  };
}
