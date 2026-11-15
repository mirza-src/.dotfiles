# tools: switch toolsets (./toolsets in the dotfiles flake) on, from anywhere
# (commands: see usage below).
#
# A switch builds the combination from $NH_FLAKE (the dotfiles checkout, as
# for nh) into the Nix profile below. Shells have its bin/ first on PATH and
# run `tools export <shell>` before each prompt (hooks in toolsets.nix), which
# brings their variables in line with the profile.

profile=$HOME/.local/state/nix/profiles/tools

# --- export: shell code for the prompt hooks -------------------------------
# State lives in the shell's own environment, so each shell (and the shells
# it starts) tracks what it loaded: _TOOLS_LOADED is the toolset's store
# path, _TOOLS_SAVED the values its variables had before, as space-separated
# VAR=<base64> (or VAR alone if it was unset).

quote() { # POSIX single quotes
  local s=${1//\'/\'\\\'\'}
  printf "'%s'" "$s"
}
fish_quote() {
  local s=${1//\\/\\\\}
  s=${s//\'/\\\'}
  printf "'%s'" "$s"
}
emit_set() { # shell var value
  case $1 in
  fish) printf 'set -gx %s %s;\n' "$2" "$(fish_quote "$3")" ;;
  *) printf 'export %s=%s;\n' "$2" "$(quote "$3")" ;;
  esac
}
emit_unset() { # shell var
  case $1 in
  fish) printf 'set -e %s;\n' "$2" ;;
  *) printf 'unset %s;\n' "$2" ;;
  esac
}

shell_export() { # shell
  local sh=$1 target="" var entry value saved=""
  local -a entries vars
  if [[ -e $profile ]]; then target=$(readlink -f "$profile"); fi
  # The common case, at every prompt: nothing changed.
  if [[ $target == "${_TOOLS_LOADED-}" ]]; then return 0; fi

  # Restore what the previous toolset changed (here too, so that the
  # values saved below are the originals).
  read -ra entries <<<"${_TOOLS_SAVED-}"
  for entry in "${entries[@]}"; do
    var=${entry%%=*}
    if [[ $entry == *=* ]]; then
      value=$(printf '%s' "${entry#*=}" | base64 -d)
      export "$var=$value"
      emit_set "$sh" "$var" "$value"
    else
      unset "$var"
      emit_unset "$sh" "$var"
    fi
  done

  # Save the new toolset's variables, then set them (expanded here, so
  # the shell gets plain values).
  if [[ -n $target && -r $target/etc/tools/vars ]]; then
    mapfile -t vars <"$target/etc/tools/vars"
    for var in "${vars[@]}"; do
      [[ -n $var ]] || continue
      if [[ -v $var ]]; then
        saved+="$var=$(printf '%s' "${!var}" | base64 -w0) "
      else
        saved+="$var "
      fi
    done
    # shellcheck source=/dev/null
    source "$target/etc/tools/env.sh"
    for var in "${vars[@]}"; do
      if [[ -n $var ]]; then emit_set "$sh" "$var" "${!var}"; fi
    done
  fi

  emit_set "$sh" _TOOLS_LOADED "$target"
  emit_set "$sh" _TOOLS_SAVED "$saved"
  # Commands came and went in bin/.
  case $sh in
  zsh) echo "rehash;" ;;
  bash) echo "hash -r;" ;;
  esac
}

if [[ ${1:-} == export ]]; then
  case ${2:-} in
  bash | zsh | fish) shell_export "$2" ;;
  *)
    echo "usage: tools export bash|zsh|fish" >&2
    exit 2
    ;;
  esac
  exit 0
fi
# ----------------------------------------------------------------------------

need_flake() {
  if [[ -z ${NH_FLAKE:-} ]]; then
    echo "tools: NH_FLAKE (the dotfiles checkout) is not set" >&2
    exit 1
  fi
}

active() { # one name per line
  if [[ -r $profile/etc/tools/names ]]; then cat "$profile/etc/tools/names"; fi
}

key() { # names... -> "a+b", sorted like the flake's attribute names
  local k
  k=$(printf '%s\n' "$@" | sed '/^$/d' | LC_ALL=C sort -u | paste -sd+ -)
  printf '%s' "${k:-none}"
}

installable() { # key
  printf '%s#legacyPackages.%s.toolsets."%s"' "$NH_FLAKE" "$TOOLS_SYSTEM" "$1"
}

switch_to() { # names...
  need_flake
  local k
  k=$(key "$@")
  mkdir -p "$(dirname "$profile")"
  nix build --profile "$profile" "$(installable "$k")"
  if [[ $k == none ]]; then echo "✓ tools: off"; else echo "✓ tools: ${k//+/ }"; fi
  echo "  (open shells pick it up by themselves at their next prompt)"
}

usage() {
  cat >&2 <<'EOF'
usage: tools                       the active toolsets
       tools list                  every toolset, the active ones marked
       tools use NAME...           switch to exactly these
       tools add NAME...           switch these on as well
       tools remove NAME...        switch these off
       tools off                   switch all off
       tools update                rebuild the active ones from the repo
       tools run NAME... -- CMD    run CMD with these, nothing is switched
       tools rollback              back to the previous switch
       tools history               every switch
EOF
  exit 2
}

mapfile -t current < <(active)

case ${1:-} in
"")
  if ((${#current[@]})); then echo "${current[*]}"; else echo "(none)"; fi
  ;;
list)
  need_flake
  nix eval --json "$NH_FLAKE#legacyPackages.$TOOLS_SYSTEM.toolsetInfo" |
    jq -r 'to_entries[] | "\(.key)\t\(.value)"' |
    while IFS=$'\t' read -r name description; do
      mark=" "
      for c in "${current[@]}"; do if [[ $c == "$name" ]]; then mark="*"; fi; done
      printf '%s %-14s %s\n' "$mark" "$name" "$description"
    done
  ;;
use)
  shift
  (($#)) || usage
  switch_to "$@"
  ;;
add)
  shift
  (($#)) || usage
  switch_to "${current[@]}" "$@"
  ;;
remove)
  shift
  (($#)) || usage
  keep=()
  for c in "${current[@]}"; do
    drop=
    for r in "$@"; do if [[ $c == "$r" ]]; then drop=1; fi; done
    if [[ -z $drop ]]; then keep+=("$c"); fi
  done
  switch_to "${keep[@]}"
  ;;
off)
  switch_to
  ;;
update)
  switch_to "${current[@]}"
  ;;
run)
  shift
  names=()
  while (($#)) && [[ $1 != -- ]]; do
    names+=("$1")
    shift
  done
  if [[ ${1:-} != -- ]] || (($# < 2)); then usage; fi
  shift
  need_flake
  out=$(nix build --no-link --print-out-paths "$(installable "$(key "${names[@]}")")")
  export PATH="$out/bin:$PATH"
  # shellcheck source=/dev/null
  source "$out/etc/tools/env.sh"
  exec "$@"
  ;;
rollback)
  nix-env --profile "$profile" --rollback
  mapfile -t current < <(active)
  if ((${#current[@]})); then echo "✓ tools: ${current[*]}"; else echo "✓ tools: off"; fi
  ;;
history)
  nix-env --profile "$profile" --list-generations
  ;;
*)
  usage
  ;;
esac
