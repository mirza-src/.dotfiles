{
  writeShellApplication,
  cachix,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  jq,
  ...
}:
# Uses the nix on PATH, so it matches the daemon.
writeShellApplication {
  name = "cachix-sync";
  runtimeInputs = [
    cachix
    coreutils
    gawk
    gnugrep
    gnused
    jq
  ];
  # Unset optional variables (GITHUB_ACTIONS, CACHIX_AUTH_TOKEN) are fine
  bashOptions = [
    "errexit"
    "pipefail"
  ];
  # Word splitting of store paths (no spaces) is intended
  excludeShellChecks = [
    "SC2046"
    "SC2086"
    "SC2207"
  ];
  text = builtins.readFile ./cachix-sync.sh;
}
