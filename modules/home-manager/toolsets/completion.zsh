# zsh completion for `tools`; @toolsets@ is replaced with the toolset names
# (toolsets.nix).
typeset -g _tools_profile=$HOME/.local/state/nix/profiles/tools

_tools() {
  local -a cmds=(
    'list:every toolset, the active ones marked'
    'use:switch to exactly these'
    'add:switch these on as well'
    'remove:switch these off'
    'off:switch all off'
    'update:rebuild the active ones from the repo'
    'run:run a command with these, nothing is switched'
    'rollback:back to the previous switch'
    'history:every switch'
  )
  local -a sets=(@toolsets@)
  if (( CURRENT == 2 )); then
    _describe 'command' cmds
    return
  fi
  case $words[2] in
    use|add) compadd -- $sets ;;
    remove)
      [[ -r $_tools_profile/etc/tools/names ]] &&
        compadd -- ${(f)"$(<$_tools_profile/etc/tools/names)"}
      ;;
    run)
      local i=${words[(i)--]}
      if (( i < CURRENT )); then
        shift $i words
        (( CURRENT -= i ))
        _normal
      else
        compadd -- $sets
        compadd -- --
      fi
      ;;
  esac
}
compdef _tools tools
