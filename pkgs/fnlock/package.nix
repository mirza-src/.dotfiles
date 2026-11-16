{
  lib,
  stdenvNoCC,
  installShellFiles,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "fnlock";
  version = "1.0";
  src = ./fnlock.sh;
  dontUnpack = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/fnlock
    patchShebangs $out/bin/fnlock
    # The script prints its own completions
    installShellCompletion --cmd fnlock \
      --bash <($out/bin/fnlock completions bash) \
      --zsh <($out/bin/fnlock completions zsh) \
      --fish <($out/bin/fnlock completions fish)
    runHook postInstall
  '';

  meta = {
    description = "Switch ASUS ROG keyboard Fn-lock (needs hid-asus-fnlock)";
    mainProgram = "fnlock";
    platforms = lib.platforms.linux;
  };
}
