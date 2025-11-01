{
  stdenv,
  fetchFromGitHub,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dms-power-usage";
  version = "main";

  src = fetchFromGitHub {
    owner = "Daniel-42-z";
    repo = finalAttrs.pname;
    rev = finalAttrs.version;
    hash = "sha256-M/H4nlAzUFrxZ01ldaR/YH1hqVN4vlBrkaCUqjtMaTM=";
  };

  patches = [
    ./power-usage.patch
  ];

  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';
})
