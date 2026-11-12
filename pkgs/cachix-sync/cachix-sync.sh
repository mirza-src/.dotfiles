# Build what this platform's hosts and homes (specialisations included) need
# that no binary cache has, and push it to the mirza Cachix cache, leaving out
# unfree packages: the cache is public, and they aren't ours to redistribute.
# The cache job in .github/workflows/check.yml runs this too.
# Pushing needs `cachix authtoken <token>` once, or CACHIX_AUTH_TOKEN.

usage() {
  cat <<EOF
Usage: cachix-sync [--no-build] [--flake DIR]

Build what this platform's hosts and homes need that no binary cache has,
and push it to the mirza Cachix cache, leaving out unfree packages.

  --no-build   only push what is already built
  --flake DIR  the dotfiles checkout (default: ~/.dotfiles)
EOF
}

cache=mirza
build=true
flake=$HOME/.dotfiles
while (($#)); do
  case $1 in
    --no-build) build=false ;;
    --flake)
      flake=$2
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$flake"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

group() { if [[ -n $GITHUB_ACTIONS ]]; then echo "::group::$1"; else echo "== $1"; fi; }
endgroup() { if [[ -n $GITHUB_ACTIONS ]]; then echo "::endgroup::"; fi; }
# `nix ... --json` keyed by full store path (older Nix: arrays of {path, ...};
# newer: keys without the store dir)
normalize='
  if type == "array" then map({key: .path, value: .}) | from_entries else . end
  | with_entries(select(.value != null)
      | .key |= if startswith("/") then . else "/nix/store/" + . end)'

system=$(nix eval --raw --impure --expr builtins.currentSystem)
case $system in
  *-linux) hosts=nixosConfigurations toplevel=config.system.build.toplevel ;;
  *-darwin) hosts=darwinConfigurations toplevel=system ;;
  *) echo "unsupported system $system" >&2; exit 1 ;;
esac
names() { nix eval --json ".#$1" --apply builtins.attrNames | jq -r '.[]'; }
targets=()
for host in $(names "$hosts"); do
  targets+=(".#$hosts.$host.$toplevel")
done
for user in $(names "legacyPackages.$system.homeConfigurations"); do
  targets+=(".#legacyPackages.$system.homeConfigurations.$user.activationPackage")
done

# Evaluate once, for the derivations and, with TRACE_UNFREE (see
# lib.allowUnfreePredicate), the names of the unfree packages among them.
if ! drvs=($(TRACE_UNFREE=1 nix path-info --impure --derivation "${targets[@]}" 2>"$tmp/eval")); then
  cat "$tmp/eval" >&2
  exit 1
fi
sed -n 's/^trace: unfree: //p' "$tmp/eval" | sort -u > "$tmp/unfree"
group "Unfree packages (never pushed)"; cat "$tmp/unfree"; endgroup

# Private sources (fetchFromGitHub { private = true; }, e.g. opsctl's: they
# fetch with the NIX_GITHUB_PRIVATE_* credentials, passed in impureEnvVars)
# and every derivation built from them: CI can't fetch them, and what's built
# from them must not land in a public cache. Grep finds the candidates
# cheaply; the attribute check skips derivations merely mentioning the names
# (like this script's own).
nix-store --query --requisites "${drvs[@]}" | grep '\.drv$' \
  | xargs grep -l NIX_GITHUB_PRIVATE > "$tmp/private-candidates" || true
: > "$tmp/private-src"
if [[ -s $tmp/private-candidates ]]; then
  xargs nix derivation show < "$tmp/private-candidates" | jq -r '
    def attr($n):
      if .structuredAttrs then .structuredAttrs[$n]
      elif .env.__json then (.env.__json | fromjson)[$n]
      else .env[$n] end;
    (.derivations // .) | to_entries[]
    | select(.value | attr("impureEnvVars")
        | (if type == "array" then join(" ") else . // "" end)
        | test("NIX_GITHUB_PRIVATE_USERNAME"))
    | .key | if startswith("/") then . else "/nix/store/" + . end
  ' > "$tmp/private-src"
fi
if [[ -s $tmp/private-src ]]; then
  nix-store --query --referrers-closure $(<"$tmp/private-src") > "$tmp/private"
else
  : > "$tmp/private"
fi
group "Private sources (never built here, never pushed)"; cat "$tmp/private-src"; endgroup

status=0
if $build; then
  # Derivations no substituter has
  if ! out=$(nix build --dry-run "${drvs[@]/%/^*}" 2>&1); then
    echo "$out" >&2
    exit 1
  fi
  missing=$(awk '/will be built:$/ { b = 1; next } /^[^ ]/ { b = 0 } b { print $1 }' <<<"$out")

  todo=()
  if [[ -n $missing ]]; then
    nix derivation show $missing | jq '
      (.derivations // .)
      | with_entries(.key |= if startswith("/") then . else "/nix/store/" + . end)
    ' > "$tmp/missing.json"

    # Never build, nor anything that needs them (building that would build
    # them too):
    # - unfree packages, and their parts named after them (-unwrapped,
    #   -extracted, ...): what's built from them refers to them, so it can't
    #   be pushed either (nvidia-settings to nvidia-x11, the 1Password
    #   security wrapper to 1password)
    # - FHS environments' root filesystems (buildFHSEnv): symlink farms;
    #   building one downloads gigabytes (steam's 32-bit libraries) and
    #   compiles nothing
    # - private sources (above)
    jq -r --rawfile unfree "$tmp/unfree" '
      ($unfree | split("\n") | map(select(. != ""))) as $unfree
      | to_entries[]
      | select(.value.name as $n
          | any($unfree[]; . as $u | $n == $u or ($n | startswith($u + "-")))
            or ($n | endswith("-fhsenv-rootfs")))
      | .key
    ' "$tmp/missing.json" > "$tmp/skip-src"
    if [[ -s $tmp/skip-src ]]; then
      nix-store --query --referrers-closure $(<"$tmp/skip-src") > "$tmp/skip"
    else
      : > "$tmp/skip"
    fi
    cat "$tmp/private" >> "$tmp/skip"

    # Also leave out:
    # - downloads (fixed-output): nothing to gain over fetching upstream
    # - those meant to be built locally (allowSubstitutes = false or
    #   preferLocalBuild: config files, symlink farms like system-path and
    #   home-manager-path, the generations): cheap, and building them would
    #   download (or build) the whole closure
    todo=($(jq -r --rawfile skip "$tmp/skip" '
      ($skip | split("\n") | map(select(. != "") | {(.): true}) | add // {}) as $skip
      # A derivation attribute: in structuredAttrs (or the older env.__json)
      # for derivations using structured attrs, else in env as a string
      # (true: "1", false: "")
      | def attr($n):
          if .structuredAttrs then .structuredAttrs[$n]
          elif .env.__json then (.env.__json | fromjson)[$n]
          else .env[$n] end;
        def local:
          (attr("allowSubstitutes") | . == false or . == "")
          or (attr("preferLocalBuild") | . == true or . == "1");
        to_entries[]
      | select((.value | local | not)
          and all(.value.outputs[]; .hash == null)
          and ($skip[.key] | not))
      | .key
    ' "$tmp/missing.json"))
  fi
  if (( ${#todo[@]} == 0 )); then
    echo "Nothing to build"
  else
    group "Building ${#todo[@]} derivations"; printf '%s\n' "${todo[@]}"; endgroup
    # Push what did build even if something failed
    nix build --keep-going --no-link "${todo[@]/%/^*}" || status=$?
  fi
fi

if [[ -z $CACHIX_AUTH_TOKEN && ! -e ${XDG_CONFIG_HOME:-$HOME/.config}/cachix/cachix.dhall ]]; then
  echo "No Cachix token (CACHIX_AUTH_TOKEN or \`cachix authtoken\`), not pushing"
  exit $status
fi

# Everything the targets' build closures hold that is in the store
nix-store --query --requisites --include-outputs "${drvs[@]}" | grep -v '\.drv$' \
  | nix path-info --json --stdin | jq "$normalize" > "$tmp/paths.json"

# Paths never to push: unfree ones, by name (outputs other than out add a
# suffix: -bin, -lib, ...; [44:] drops "/nix/store/<hash>-"), and the outputs
# of derivations built from private sources. (Not by deriver: a path records
# the .drv it was first built from, and an equivalent .drv, e.g. with its
# source fetched differently, has another name but the same outputs.)
# Cachix pushes a path's whole closure, so everything referring to them
# stays out too.
excluded=$(
  jq -r --rawfile u "$tmp/unfree" '
    ($u | split("\n") | map(select(. != ""))) as $u
    | keys[]
    | select(.[44:] as $n | any($u[]; . as $x | $n == $x or ($n | startswith($x + "-"))))
  ' "$tmp/paths.json"
  if [[ -s $tmp/private ]]; then
    # Only those in the store: referrers-closure needs valid paths
    nix-store --query --outputs $(<"$tmp/private") | while read -r p; do
      if [[ -e $p ]]; then echo "$p"; fi
    done
  fi
)
if [[ -n $excluded ]]; then
  nix-store --query --referrers-closure $excluded > "$tmp/exclude"
else
  : > "$tmp/exclude"
fi

# Built here (ultimate: not downloaded), not a download or a copied source (ca)
jq -r --rawfile ex "$tmp/exclude" '
  ($ex | split("\n") | map(select(. != "") | {(.): true}) | add // {}) as $ex
  | to_entries[]
  | select(.value.ultimate == true and .value.ca == null)
  | .key | select($ex[.] | not)
' "$tmp/paths.json" > "$tmp/push"

if [[ ! -s $tmp/push ]]; then
  echo "Nothing to push"
  exit $status
fi
group "Pushing $(wc -l < "$tmp/push" | tr -d ' ') paths to $cache"; cat "$tmp/push"; endgroup
cachix push "$cache" < "$tmp/push"
exit $status
