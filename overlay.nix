final: prev:
let
  lib = prev.lib;
  localPackages = (
    lib.packagesFromDirectoryRecursive {
      inherit (final) callPackage newScope;
      directory = ./pkgs;
    }
  );
in
{
  vscode = (prev.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: {
    src = prev.fetchurl {
      name = "VSCode_Insiders_linux-x64.tar.gz";
      url = "https://code.visualstudio.com/sha/download?build=insider&os=linux-x64";
      sha256 = "sha256-yP9fYIKaJHI0wKvVzEN2NVEvd5zXcK235+cOMW96y48=";
    };
    version = "latest";
    buildInputs = oldAttrs.buildInputs ++ [
      prev.krb5
      prev.libsoup_3
      prev.webkitgtk_4_1
    ];
  });
}
// (lib.mapAttrs (
  name: pkg:
  if lib.isAttrs pkg then
    (prev.${name} or { }) // pkg
  else if lib.isDerivation pkg then
    pkg
  else
    prev.${name} or pkg
) localPackages)
