#!/usr/bin/env bash
# v0.8.0: cx CLI bash completion.
#
# Install: source this file from ~/.bashrc or symlink to
#   /etc/bash_completion.d/cx (system-wide) or
#   ~/.local/share/bash-completion/completions/cx (user).

_cx_subcmds() {
  # v0.8.0 surface — `select` retired (CXPath now first-class value
  # kind per code.md §5.5; use `cx eval` with a //path expression).
  # `diagram` renders a data-shaped diagram; `code-diagram`/`code-tree`
  # render the program AST; `lock` manages the dependency lockfile.
  echo "fmt canonical hash eq diff lint validate table demo scaffold eval diagram code-diagram code-tree lock lsp"
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
    eval)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--data= --target=" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    diagram)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--format= --output= --depth=" -- "$cur") )
          return 0
          ;;
        --format=*)
          COMPREPLY=( $(compgen -W "mermaid graphviz" -- "${cur#--format=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--format=}" )
          return 0
          ;;
      esac
      ;;
    code-diagram)
      case "$cur" in
        --level=*)
          COMPREPLY=( $(compgen -W "min compact full" -- "${cur#--level=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--level=}" )
          return 0
          ;;
        --*)
          COMPREPLY=( $(compgen -W "--level=" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    lock)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--check --update --output= --help" -- "$cur") )
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

  # Default: file completion for CX-family inputs
  COMPREPLY=( $(compgen -f -X '!*.@(cx|xml|json|yaml|toml|arrow|parquet)' -- "$cur") )
}

complete -F _cx_complete cx
