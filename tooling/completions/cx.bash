#!/usr/bin/env bash
# Q7 v0.7.0: cx CLI bash completion.
#
# Install: source this file from ~/.bashrc or symlink to
#   /etc/bash_completion.d/cx (system-wide) or
#   ~/.local/share/bash-completion/completions/cx (user).

_cx_subcmds() {
  echo "fmt canonical hash eq diff lint validate table demo scaffold eval select upgrade-config lsp"
}

_cx_table_verbs() {
  echo "info dump load"
}

_cx_complete() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$(_cx_subcmds)" -- "$cur") )
    return 0
  fi

  local subcmd="${COMP_WORDS[1]}"
  case "$subcmd" in
    table)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$(_cx_table_verbs)" -- "$cur") )
        return 0
      fi
      case "$cur" in
        --to=*)
          COMPREPLY=( $(compgen -W "cx parquet arrow" -- "${cur#--to=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--to=}" )
          return 0
          ;;
        --from=*)
          COMPREPLY=( $(compgen -W "cx parquet arrow" -- "${cur#--from=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--from=}" )
          return 0
          ;;
        --*)
          COMPREPLY=( $(compgen -W "--to= --from= --output=" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    upgrade-config)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--dry-run --lint-ref-elements --help" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    eval)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--input= --target=" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    lsp)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--verbose --help" -- "$cur") )
          return 0
          ;;
      esac
      return 0
      ;;
  esac

  # Default: file completion for .cx / .cxl / .xml / .json
  COMPREPLY=( $(compgen -f -X '!*.@(cx|cxl|xml|json|md|yaml|toml|arrow|parquet)' -- "$cur") )
}

complete -F _cx_complete cx
