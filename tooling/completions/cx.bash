#!/usr/bin/env bash
# cx CLI bash completion.
#
# Install: source this file from ~/.bashrc or symlink to
#   /etc/bash_completion.d/cx (system-wide) or
#   ~/.local/share/bash-completion/completions/cx (user).
#
# Kept in lockstep with the dispatch table in vcx/cmd/main.v —
# `make check-completions-drift` fails if a subcommand is missing here.

_cx_subcmds() {
  # `select` is the CXPath query subcommand (#462; cli.md §3.8):
  # `cx select 'PATH' [FILE]`, flagless.
  # `diagram` renders the program as a diagram; `code-diagram`/`code-tree`
  # render the program AST; `lock` manages the dependency lockfile;
  # `store-*` are the CSRP store-service verbs (serve / health probe /
  # token mint / KEK rotation); `fabric-serve` is the fabric daemon.
  echo "fmt canonical hash eq diff lint schema tools validate table demo scaffold xap eval primer version select diagram code-diagram code-tree lock store-serve store-health store-rotate-kek fabric-serve lsp"
}

_cx_table_verbs() {
  echo "info dump load"
}

# Capability grants (security.md §3): deny-by-default; --allow-all opts out.
_cx_allow_flags() {
  echo "--allow-all --allow-read --allow-write --allow-net --allow-env --allow-clock --allow-random --allow-subprocess --allow-eval --allow-secret-reveal"
}

# Top-level (no subcommand) conversion / evaluation flags — vcx/cmd/main.v.
# `--data=` is the run-surface separate data input (#415): bound as $doc.
_cx_toplevel_flags() {
  echo "--ast --cx --xml --json --yaml --toml --md --csv --tsv --psv --cxcol --compact --lossless --from= --to= --include-root= --data= -e --expression $(_cx_allow_flags) -v --version -h --help"
}

_cx_complete() {
  local cur prev words cword
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    if [[ "$cur" == -* ]]; then
      COMPREPLY=( $(compgen -W "$(_cx_toplevel_flags)" -- "$cur") )
    else
      COMPREPLY=( $(compgen -W "$(_cx_subcmds)" -- "$cur") )
    fi
    return 0
  fi

  local subcmd="${COMP_WORDS[1]}"
  case "$subcmd" in
    fmt)
      case "$cur" in
        -*)
          COMPREPLY=( $(compgen -W "-w --migrate-predicates --collapse-lets" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    diff)
      case "$cur" in
        --format=*)
          COMPREPLY=( $(compgen -W "unified json summary" -- "${cur#--format=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--format=}" )
          return 0
          ;;
        --*)
          COMPREPLY=( $(compgen -W "--format= --no-color --color" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    lint)
      case "$cur" in
        --format=*)
          COMPREPLY=( $(compgen -W "text json summary" -- "${cur#--format=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--format=}" )
          return 0
          ;;
        --fail-on=*)
          COMPREPLY=( $(compgen -W "info warn error none" -- "${cur#--fail-on=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--fail-on=}" )
          return 0
          ;;
        --*)
          COMPREPLY=( $(compgen -W "--format= --fail-on= --disable= --only= --config= --no-config" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    validate)
      case "$cur" in
        --fail-on=*)
          COMPREPLY=( $(compgen -W "info warn error none" -- "${cur#--fail-on=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--fail-on=}" )
          return 0
          ;;
        --mode=*)
          COMPREPLY=( $(compgen -W "open strict closed" -- "${cur#--mode=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--mode=}" )
          return 0
          ;;
        --schema=*)
          local prefix="--schema="
          COMPREPLY=( $(compgen -f -X '!*.cxs' -- "${cur#--schema=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/$prefix}" )
          return 0
          ;;
        --*)
          COMPREPLY=( $(compgen -W "--schema= --fail-on= --mode= --apply-defaults" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    schema)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "infer" -- "$cur") )
        return 0
      fi
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--sample= --output=" -- "$cur") )
          return 0
          ;;
      esac
      _cx_files
      return 0
      ;;
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
          COMPREPLY=( $(compgen -W "--to= --from= --output= --strict" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    scaffold)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "config data doc log table" -- "$cur") )
        return 0
      fi
      ;;
    eval)
      case "$cur" in
        --target=*)
          COMPREPLY=( $(compgen -W "text cx json yaml xml csv tsv mermaid svg png" -- "${cur#--target=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--target=}" )
          return 0
          ;;
        -*)
          COMPREPLY=( $(compgen -W "--data= --target= -e --expression -d --data-text $(_cx_allow_flags)" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    diagram)
      case "$cur" in
        --format=*)
          COMPREPLY=( $(compgen -W "mermaid svg png" -- "${cur#--format=}") )
          COMPREPLY=( "${COMPREPLY[@]/#/--format=}" )
          return 0
          ;;
        -*)
          COMPREPLY=( $(compgen -W "--format= -o --allow-subprocess" -- "$cur") )
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
    store-serve)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--config= --exit-on-stdin-eof $(_cx_allow_flags)" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    fabric-serve)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--config= --exit-on-stdin-eof $(_cx_allow_flags)" -- "$cur") )
          return 0
          ;;
      esac
      ;;
    store-health)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--url=" -- "$cur") )
          return 0
          ;;
      esac
      return 0
      ;;
    store-rotate-kek)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--url= --encrypt-key-id= --new-key-id=" -- "$cur") )
          return 0
          ;;
      esac
      return 0
      ;;
    lsp)
      case "$cur" in
        --*)
          COMPREPLY=( $(compgen -W "--verbose" -- "$cur") )
          return 0
          ;;
      esac
      return 0
      ;;
  esac

  # Default: file completion for CX-family inputs (.cx program/data,
  # .cxd conformance fixture, .cxs schema) + convertible foreign formats.
  COMPREPLY=( $(compgen -f -X '!*.@(cx|cxd|cxs|xml|json|yaml|yml|toml|md|csv|tsv|psv|arrow|parquet)' -- "$cur") )
}

complete -F _cx_complete cx
