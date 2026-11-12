{
  lib,
  fetchurl,
  jdk,
  makeWrapper,
  stdenv,
  writeShellApplication,
  curl,
  jq,
  nix-update,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "umple-bin";
  # Version of the release jar: <tag version>.<build>.<commit>
  version = "1.35.0.7523.c616a4dce";

  src = fetchurl {
    name = "umple.jar";
    url = "https://github.com/umple/umple/releases/download/v${lib.versions.pad 3 finalAttrs.version}/umple-${finalAttrs.version}.jar";
    sha256 = "sha256:1cqbz2hf09mkvgl7s953l28hzv089c7xkp7rxcc68f9jfixn6fs9";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    jdk
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    makeWrapper ${jdk}/bin/java $out/bin/umple \
      --add-flags -jar --add-flags $src

    runHook postInstall
  '';

  # Release tags (v1.38.0) lack the build and commit in the jar's name
  # (umple-1.38.0.8918.bda708970.jar), so take the version from the jar.
  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-umple-bin";
    runtimeInputs = [
      curl
      jq
      nix-update
    ];
    text = ''
      version=$(curl -fsSL https://api.github.com/repos/umple/umple/releases/latest |
        jq -r '.assets[].name | capture("^umple-(?<v>[0-9][^-]*)\\.jar$").v')
      nix-update ''${UPDATE_NIX_FLAKE:+--flake} --version "$version" "$UPDATE_NIX_ATTR_PATH"
    '';
  });
})
