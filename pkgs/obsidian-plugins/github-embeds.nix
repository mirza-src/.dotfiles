# TODO: Generalize into a single function
{
  stdenv,
  ...
}:
stdenv.mkDerivation rec {
  pname = "obsidian.plugins.github-embeds";
  version = "1.0.7";
  phases = [
    "installPhase"
    "fixupPhase"
  ];

  owner = "MrGVSV";
  repo = "obsidian-github-embeds";
  release = version;

  baseUrl = "https://github.com/${owner}/${repo}/releases/download/${release}";

  main = (
    builtins.fetchurl {
      url = "${baseUrl}/main.js";
      sha256 = "sha256:04d9hpfiy5j06rgsi98bj6wg2j5ai8ldp2wmm8fh218m44bhpwga";
    }
  );
  styles = (
    builtins.fetchurl {
      url = "${baseUrl}/styles.css";
      sha256 = "sha256:0lbg19p414ca48iqhp523ivx22d6h1m3bbaixj8npfyfa6rj2ksc";
    }
  );
  manifest = (
    builtins.fetchurl {
      url = "${baseUrl}/manifest.json";
      sha256 = "sha256:06fzlgcl8k9sx9iids4ck1xqdbihkaip7a4yca5wz0llwc1lf4g3";
    }
  );

  installPhase = ''
    mkdir -p $out
    cp $main $out/main.js
    cp $styles $out/styles.css
    cp $manifest $out/manifest.json
  '';
}

# NOTE: Alternative for building from source
# buildNpmPackage (finalAttrs: {
#   pname = "obsidian.plugins.github-embeds";
#   version = "1.0.7";

#   src = fetchFromGitHub {
#     owner = "MrGVSV";
#     repo = "obsidian-github-embeds";
#     tag = finalAttrs.version;
#     hash = "sha256-Z0SCw22EJI6zcqkxI/QeSZ17qn98iA5vwlakW5/qT6U=";
#   };

#   npmDepsHash = "sha256-9faMOK8mwF1IoiziTxzX1DwgtEBUWbwMOkNeb0Srki4=";

#   installPhase = ''
#     mkdir -p $out
#     cp ./manifest.json $out/manifest.json
#     cp ./main.js $out/main.js
#     cp ./styles.css $out/styles.css
#   '';
# })
