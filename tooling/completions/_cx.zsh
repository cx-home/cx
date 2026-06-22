#compdef cx
# cx CLI zsh completion.
#
# Install: place in a directory on $fpath (e.g.
#   /usr/local/share/zsh/site-functions/_cx or
#   ~/.zfunc/_cx) and add `autoload -U _cx` to .zshrc.

_cx() {
  # `select` retired (CXPath is a first-class value kind
  # per code.md §5.5, use `cx eval` with a //path expression);
  # `diagram` renders a DATA-shaped diagram, `code-diagram` / `code-tree`
  # render the PROGRAM AST; `lock` manages the dependency lockfile.
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
    'demo:Run the cx demo'
    'scaffold:Scaffold a new CX project'
    'eval:Evaluate a CX program'
    'diagram:Render a diagram from a CX source (mermaid / graphviz)'
    'code-diagram:Render the program AST to a Mermaid diagram'
    'code-tree:Render the program AST as an indented tree'
    'lock:Manage the dependency lockfile (--check / --update)'
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
        '*:file:_files -g "*.(cx|parquet|arrow)"'
      ;;
    eval)
      _arguments \
        '--data=[input CX file (- for stdin)]:file:_files -g "*.cx"' \
        '--target=[output target]:target:(text cx json yaml xml csv tsv)' \
        '*:program:_files -g "*.cx"'
      ;;
    diagram)
      _arguments \
        '--format=[diagram format]:format:(mermaid graphviz)' \
        '--output=[output file]:file:_files' \
        '--depth=[max depth]:depth:' \
        '*:program:_files -g "*.cx"'
      ;;
    code-diagram)
      _arguments \
        '--level=[detail level]:level:(min compact full)' \
        '*:program:_files -g "*.cx"'
      ;;
    code-tree)
      _arguments \
        '*:program:_files -g "*.cx"'
      ;;
    lock)
      _arguments \
        '--check[verify the lockfile is up to date]' \
        '--update[regenerate the lockfile]' \
        '--output=[lockfile path]:file:_files' \
        '--help[show usage]' \
        '*:manifest:_files -g "*.cx"'
      ;;
    lsp)
      _arguments \
        '--verbose[trace incoming methods on stderr]' \
        '--help[show usage]'
      ;;
    *)
      _files -g '*.(cx|xml|json|yaml|toml|arrow|parquet)'
      ;;
  esac
}

_cx "$@"
