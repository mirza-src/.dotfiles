{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  rustPlatform,
  pinentry-qt,
  libargon2,
  ...
}:
let
  version = "1.11.6-dms.5";

  # Same revision the dms-plugin-registry pins for "bitwarden".
  src = fetchFromGitHub {
    owner = "coldi1337";
    repo = "dms-bitwarden-cli";
    rev = "94ef65e27b02fdbb650529d4c1fc5aa643e9676a";
    hash = "sha256-mP4sCbgDZX0vU30zb5Kb6L6VVvqhRERvEof+s6pciVY=";
  };

  # The three helpers are separate crates, each with its own Cargo.lock
  # (all crates.io dependencies, no native libraries). Upstream pins rustc
  # 1.98.0 in rust-toolchain.toml only for byte-reproducible release builds;
  # Cargo.toml asks for rust-version 1.85, so nixpkgs' rustc is fine.
  mkHelper =
    {
      crate,
      name,
      cargoHash,
      checkFlags ? [ ],
    }:
    rustPlatform.buildRustPackage {
      pname = name;
      inherit
        version
        src
        cargoHash
        checkFlags
        ;
      sourceRoot = "${src.name}/${crate}";
      meta.mainProgram = name;
    };

  helpers = {
    vault = mkHelper {
      crate = "vault";
      name = "qs-bitwarden-vault";
      cargoHash = "sha256-wfiuE07Avf2pnoVfK4A60eAQ+EyzFvnVOj+vwR6H+JM=";
    };
    unlock-key = mkHelper {
      crate = "unlock-key";
      name = "qs-bitwarden-unlock-key";
      cargoHash = "sha256-k8HmVZT2Cwh1l2ElokM1/Qug+7sxyDs6oqh8AS8zgS4=";
    };
    agent = mkHelper {
      crate = "agent";
      name = "qs-bitwarden-ssh-agent";
      cargoHash = "sha256-D99/+aH/u07zUv7abWf+zYtChdbqwT9pqb1bG1MaM3Y=";
      # Runs a hardcoded /usr/bin/ssh-keygen, absent in the build sandbox.
      checkFlags = [ "--skip=disposable_key_load_identity_and_approved_sign_cross_the_real_socket" ];
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "dms-plugin-bitwarden";
  inherit version src;

  dontConfigure = true;
  dontBuild = true;
  # Keep the helpers exactly as cargo produced them, and leave upstream's
  # unused bin/ artifact alone.
  dontStrip = true;
  dontPatchELF = true;

  # Only the panel's JS is patched; the crate sources must stay pristine so
  # the runtime source hash matches the stamp.
  postPatch = ''
    # pinentry and argon2 are looked up on PATH, and neither is installed on
    # this system; point the automatic choice / quick-unlock KDF at the store.
    substituteInPlace BitwardenModel.js \
      --replace-fail 'var PINENTRY_PREFERRED_PROGRAM = "pinentry-qt"' \
                     'var PINENTRY_PREFERRED_PROGRAM = "${lib.getExe' pinentry-qt "pinentry-qt"}"' \
      --replace-fail '| argon2 \"$2\" -id' \
                     '| ${lib.getExe' libargon2 "argon2"} \"$2\" -id' \
      --replace-fail 'if command -v argon2 >/dev/null' \
                     'if command -v ${lib.getExe' libargon2 "argon2"} >/dev/null'
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r . $out

    # The plugin only runs Cargo's "development" output:
    # <crate>/target/debug/<name>, inspected with --version and --self-test.
    install -Dm755 ${lib.getExe helpers.vault} $out/vault/target/debug/qs-bitwarden-vault
    install -Dm755 ${lib.getExe helpers.unlock-key} $out/unlock-key/target/debug/qs-bitwarden-unlock-key
    install -Dm755 ${lib.getExe helpers.agent} $out/agent/target/debug/qs-bitwarden-ssh-agent

    runHook postInstall
  '';

  # Stamps last, after fixup, from the crate files in their final place, with
  # the plugin's own script, so the runtime check reports sourceStamp=match.
  postFixup = ''
    for pair in vault:qs-bitwarden-vault unlock-key:qs-bitwarden-unlock-key agent:qs-bitwarden-ssh-agent; do
      crate=''${pair%%:*}
      name=''${pair#*:}
      bash $out/scripts/helper-source-hash.sh $out/$crate > $out/$crate/target/debug/$name.source-sha256
      $out/$crate/target/debug/$name --self-test
    done
  '';

  passthru = {
    # Pinned to the revision the dms-plugin-registry uses.
    skipUpdate = true;
    inherit helpers;
  };

  meta = {
    description = "Bitwarden / Vaultwarden in DankMaterialShell, with Nix-built vault, quick-unlock and SSH helpers";
    homepage = "https://github.com/coldi1337/dms-bitwarden-cli";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
