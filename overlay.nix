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
  vscode = (prev.vscode.override { isInsiders = true; }).overrideAttrs (oldAttrs: rec {
    src = prev.fetchurl {
      # https://update.code.visualstudio.com/api/commits/{insider,stable}/{linux-x64,darwin} -- List commits for builds
      # https://update.code.visualstudio.com/api/versions/commit:COMMIT_ID/{linux-x64,darwin}/{insider,stable} -- Get download URL for commit
      url = "https://vscode.download.prss.microsoft.com/dbazure/download/insider/${version}/code-insider-x64-1771909975.tar.gz";
      sha256 = "sha256-gseCpgZfEnk4XEjad2VylDfH72GVWdXXgc4d0RqMQgk=";
    };
    version = "88757eaab9989a8e9f1c6254b3fcdd9ce4d8bb98";
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
