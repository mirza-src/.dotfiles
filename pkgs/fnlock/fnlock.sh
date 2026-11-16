#!/usr/bin/env bash
# Keyboard Fn-lock through hid-asus-fnlock's fn_lock attribute.
# on = F1-F12 without Fn, off = media/hotkeys without Fn.
set -euo pipefail

# command:description, the one list usage and completions are built from
commands=(
  "on:F1-F12 without Fn"
  "off:media keys without Fn"
  "toggle:switch Fn-lock (default)"
  "status:show Fn-lock state"
  "reapply:re-send the current state to the keyboard"
  "completions:print shell completions (bash, zsh, fish)"
)

usage() {
  echo "usage: fnlock [command]" >&2
  for c in "${commands[@]}"; do
    printf '  %-12s %s\n' "${c%%:*}" "${c#*:}" >&2
  done
  exit 2
}

completions() {
  case "${1:-}" in
    bash)
      local names=()
      for c in "${commands[@]}"; do names+=("${c%%:*}"); done
      cat <<EOF
_fnlock() {
  if [ "\$COMP_CWORD" -eq 1 ]; then
    mapfile -t COMPREPLY < <(compgen -W "${names[*]}" -- "\${COMP_WORDS[1]}")
  elif [ "\$COMP_CWORD" -eq 2 ] && [ "\${COMP_WORDS[1]}" = completions ]; then
    mapfile -t COMPREPLY < <(compgen -W "bash zsh fish" -- "\${COMP_WORDS[2]}")
  fi
}
complete -F _fnlock fnlock
EOF
      ;;
    zsh)
      echo '#compdef fnlock'
      echo 'if (( CURRENT == 3 )) && [[ $words[2] == completions ]]; then'
      echo '  _values shell bash zsh fish'
      echo 'elif (( CURRENT == 2 )); then'
      echo "  _arguments '1:command:(("
      for c in "${commands[@]}"; do
        printf '    %s\\:"%s"\n' "${c%%:*}" "${c#*:}"
      done
      echo "  ))'"
      echo 'fi'
      ;;
    fish)
      echo 'complete -c fnlock -f'
      for c in "${commands[@]}"; do
        printf "complete -c fnlock -n __fish_use_subcommand -a %s -d '%s'\n" "${c%%:*}" "${c#*:}"
      done
      echo "complete -c fnlock -n '__fish_seen_subcommand_from completions' -a 'bash zsh fish'"
      ;;
    *)
      echo "usage: fnlock completions bash|zsh|fish" >&2
      exit 2
      ;;
  esac
}

# Handled before touching sysfs, so it works at build time too
case "${1:-}" in
  completions)
    completions "${2:-}"
    exit
    ;;
  -h | --help | help) usage ;;
esac

f=
for a in /sys/bus/hid/devices/*/fn_lock; do
  [ -e "$a" ] && f=$a && break
done
[ -n "$f" ] || {
  echo "fnlock: no fn_lock attribute (hid-asus-fnlock not loaded?)" >&2
  exit 1
}

cur=$(<"$f")
case "${1:-toggle}" in
  on) echo 1 >"$f" ;;
  off) echo 0 >"$f" ;;
  toggle) echo $((1 - cur)) >"$f" ;;
  # e.g. after Windows changed it behind the driver's back
  reapply) echo "$cur" >"$f" ;;
  status) ;;
  *) usage ;;
esac

[ "$(<"$f")" = 1 ] && echo on || echo off
