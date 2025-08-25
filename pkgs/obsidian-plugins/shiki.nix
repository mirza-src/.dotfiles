{
  stdenv,
  ...
}:
stdenv.mkDerivation rec {
  pname = "obsidian.plugins.shiki";
  version = "0.5.0";
  phases = [
    "installPhase"
    "fixupPhase"
  ];

  owner = "mProjectsCode";
  repo = "obsidian-shiki-plugin";
  release = version;

  baseUrl = "https://github.com/${owner}/${repo}/releases/download/${release}";

  main = (
    builtins.fetchurl {
      url = "${baseUrl}/main.js";
      sha256 = "sha256:0l91qrcsi7zq94rvw85xgdrirg5msxm45x18w1hyq1hicl1dzwzi";
    }
  );
  styles = (
    builtins.fetchurl {
      url = "${baseUrl}/styles.css";
      sha256 = "sha256:04ixyz2gfl37w4zlmmp6nrh8pqxi2nvvgwnhi89h04jf0bhwsyr8";
    }
  );
  manifest = (
    builtins.fetchurl {
      url = "${baseUrl}/manifest.json";
      sha256 = "sha256:1ss94qwpinjv14h3algwfprmbsfkf8gqn0f8n5dvpz0ycvqvcqvq";
    }
  );

  installPhase = ''
    mkdir -p $out
    cp $main $out/main.js
    cp $styles $out/styles.css
    cp $manifest $out/manifest.json
  '';
}
