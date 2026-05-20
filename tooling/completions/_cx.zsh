#compdef cx
# Q7 v0.7.0: cx CLI zsh completion.
#
# Install: place in a directory on $fpath (e.g.
#   /usr/local/share/zsh/site-functions/_cx or
#   ~/.zfunc/_cx) and add `autoload -U _cx` to .zshrc.

_cx() {
  local -a subcmds
  subcmds=(
    'fmt:Format CX text canonically'
    'canonical:Strict canonical form for hashing'
    'hash:SHA-256 of strict canonical bytes'
    'eq:Compare two files at canonical-equality'
    'diff:Semantic diff between two CX files'
    'lint:Lint a CX file'
    'validate:Validate against a schema'
    'table:Table operations (info/dump/load)'
    'demo:Run the v0.7.0 demo'
    'scaffold:Scaffold a new CX project'
    'eval:Evaluate a CX template'
    'select:Run a CXPath query against a CX file'
    'upgrade-config:Migrate v0.6.0 source to v0.7.0 conventions'
    'lsp:Run the cx Language Server over stdio (JSON-RPC 2.0)'
  )

  if (( CURRENT == 2 )); then
    _describe 'subcommand' subcmds
    return 0
  fi

  case "${words[2]}" in
    table)
      if (( CURRENT == 3 )); then
        _values 'verb' 'info[show column count/row count]' \
                       'dump[emit table in chosen format]' \
                       'load[ingest table from chosen format]'
        return 0
      fi
      _arguments \
        '--to=[output format]:format:(cx parquet arrow)' \
        '--from=[input format]:format:(cx parquet arrow)' \
        '--output=[output file]:file:_files' \
        '*:file:_files -g "*.(cx|cxl|parquet|arrow)"'
      ;;
    upgrade-config)
      _arguments \
        '--dry-run[report changes without writing]' \
        '--lint-ref-elements[scan for M7 candidates]' \
        '--help[show usage]' \
        '*:file or dir:_files'
      ;;
    eval)
      _arguments \
        '--input=[input CX file]:file:_files -g "*.(cx|cxl)"' \
        '--target=[output target]:target:(text html cx markdown json yaml xml csv tsv)' \
        '*:program:_files -g "*.(cx|cxl)"'
      ;;
    lsp)
      _arguments \
        '--verbose[trace incoming methods on stderr]' \
        '--help[show usage]'
      ;;
    *)
      _files -g '*.(cx|cxl|xml|json|md|yaml|toml|arrow|parquet)'
      ;;
  esac
}

_cx "$@"
