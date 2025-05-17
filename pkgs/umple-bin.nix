{ jdk, makeWrapper, stdenv, ... }: stdenv.mkDerivation (finalAttrs: {
  name = "umple-bin";

  src = builtins.fetchurl {
    name = "umple.jar";
    url = "https://github.com/umple/umple/releases/download/v1.35.0/umple-1.35.0.7523.c616a4dce.jar";
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
})
