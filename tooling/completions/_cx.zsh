#compdef cx
# cx CLI zsh completion.
#
# Install: place in a directory on $fpath (e.g.
#   /usr/local/share/zsh/site-functions/_cx or
#   ~/.zfunc/_cx) and add `autoload -U _cx` to .zshrc.
#
# Kept in lockstep with the dispatch table in vcx/cmd/main.v —
# `make check-completions-drift` fails if a subcommand is missing here.

_cx() {
  # `select` is the CXPath query subcommand (#462; cli.md §3.8):
  # `cx select 'PATH' [FILE]`, flagless;
  # `diagram` renders the program as a diagram, `code-diagram` / `code-tree`
  # render the PROGRAM AST; `lock` manages the dependency lockfile;
  # `store-*` are the CSRP store-service verbs.
  local -a subcmds allow_flags
  subcmds=(
    'fmt:Format CX text canonically (lossless)'
    'canonical:Strict canonical form for hashing'
    'hash:SHA-256 of strict canonical bytes'
    'eq:Compare two files at canonical-equality'
    'diff:Semantic diff between two CX files'
    'lint:Lint a CX file'
    'schema:Schema verb family — infer an open-mode .cxs from a corpus'
    'tools:Agent-tool verb family — project command defs to MCP tool descriptors'
    'validate:Validate against a schema'
    'table:Table operations (info/dump/load)'
    'demo:Run the cx demo'
    'xap:XAP project tooling — cx xap init NAME scaffolds one'
    'scaffold:Scaffold a typed CX skeleton (config/data/doc/log/table)'
    'eval:Evaluate a CX program'
    'primer:Print the LLM onboarding primer for this binary'
    'version:Version / build info (same as -v / --version)'
    'select:CXPath query over a document (matches in canonical CX)'
    'diagram:Render a CX program as a diagram (mermaid / svg / png)'
    'code-diagram:Render the program AST to a Mermaid diagram'
    'code-tree:Render the program AST as an indented tree'
    'lock:Manage the dependency lockfile (--check / --update)'
    'store-serve:Run the CSRP store-service daemon'
    'store-health:Readiness probe against a running store service'
    'store-rotate-kek:Rotate the store key-encryption key'
    'fabric-serve:Run the fabric event-stream daemon'
    'lsp:Run the cx Language Server over stdio (JSON-RPC 2.0)'
  )
  # Capability grants (security.md §3): deny-by-default; --allow-all opts out.
  allow_flags=(
    '--allow-all[grant all capabilities (trusted-local opt-out)]'
    '--allow-read[grant filesystem read]'
    '--allow-write[grant filesystem write]'
    '--allow-net=-[grant network access (optionally host\:port)]'
    '--allow-env[grant environment access]'
    '--allow-clock[grant clock access]'
    '--allow-random[grant randomness]'
    '--allow-subprocess[grant subprocess spawning]'
    '--allow-eval[grant dynamic eval]'
    '--allow-secret-reveal[grant secret reveal]'
  )

  if (( CURRENT == 2 )); then
    if [[ "${words[2]}" == -* ]]; then
      # Top-level (no subcommand) conversion / evaluation flags — vcx/cmd/main.v.
      _arguments \
        '--ast[dump the parsed AST]' \
        '--cx[emit canonical CX]' \
        '--xml[emit XML]' \
        '--json[emit JSON]' \
        '--yaml[emit YAML]' \
        '--toml[emit TOML]' \
        '--md[emit Markdown]' \
        '--csv[emit CSV]' \
        '--tsv[emit TSV]' \
        '--psv[emit PSV]' \
        '--cxcol[emit columnar CX]' \
        '--compact[compact output]' \
        '--lossless[XML carries per-value types for exact round-trip]' \
        '--from=[input format (selects the convert pipeline)]:format:(cx xml json yaml toml md)' \
        '--to=[output format]:format:(cx xml json yaml toml md csv tsv psv)' \
        '--include-root=[resolve \[?cx include\] against this root]:dir:_files -/' \
        '--data=[separate data input, bound as $doc (- for stdin)]:file:_files -g "*.(cx|cxd)"' \
        '-e[inline program expression]:program:' \
        '--expression[inline program expression]:program:' \
        "${allow_flags[@]}" \
        '(-v --version)'{-v,--version}'[print version]' \
        '(-h --help)'{-h,--help}'[show usage]'
    else
      _describe 'subcommand' subcmds
    fi
    return 0
  fi

  case "${words[2]}" in
    fmt)
      _arguments \
        '-w[write changed files in place]' \
        '--migrate-predicates[predicate-surface cutover sweep]' \
        '--collapse-lets[collapse cascading let idioms]' \
        '*:file:_files -g "*.(cx|cxd|md)"'
      ;;
    diff)
      _arguments \
        '--format=[output format]:format:(unified json summary)' \
        '--no-color[disable color output]' \
        '--color=-[color output]:when:(auto always never)' \
        '*:file:_files -g "*.(cx|cxd)"'
      ;;
    lint)
      _arguments \
        '--format=[output format]:format:(text json summary)' \
        '--fail-on=[exit-1 severity threshold]:severity:(info warn error none)' \
        '--disable=[comma-separated rule IDs to disable]:ids:' \
        '--only=[run only this rule ID]:id:' \
        '--config=[explicit .cxlint.cx path]:file:_files' \
        '--no-config[skip .cxlint.cx discovery]' \
        '*:file:_files -g "*.(cx|cxd)"'
      ;;
    validate)
      _arguments \
        '--schema=[schema file]:schema:_files -g "*.cxs"' \
        '--fail-on=[exit-1 severity threshold]:severity:(info warn error none)' \
        '--mode=[schema mode override]:mode:(open strict closed)' \
        '--apply-defaults[apply schema defaults to the document]' \
        '*:file:_files -g "*.(cx|cxd)"'
      ;;
    schema)
      if (( CURRENT == 3 )); then
        _values 'verb' 'infer[synthesize an open-mode .cxs schema from a corpus]'
        return 0
      fi
      _arguments \
        '--sample=[bound the corpus to the first N documents]:count:' \
        '--output=[write the schema to a file]:file:_files' \
        '*:file:_files'
      return 0
      ;;
    tools)
      if (( CURRENT == 3 )); then
        _values 'verb' 'export[project a module'"'"'s command defs to the MCP tools/list array (offline registration)]'
        return 0
      fi
      _arguments \
        '--output=[write the tools array to a file]:file:_files' \
        '*:file:_files -g "*.cx"'
      return 0
      ;;
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
        '--strict[strict column typing]' \
        '*:file:_files -g "*.(cx|parquet|arrow)"'
      ;;
    scaffold)
      if (( CURRENT == 3 )); then
        _values 'kind' 'config[typed config skeleton]' \
                       'data[typed data entities]' \
                       'doc[mixed prose + structured data]' \
                       'log[logfmt-mode event lines]' \
                       'table[column-typed rows]'
        return 0
      fi
      ;;
    eval)
      _arguments \
        '--data=[input CX file (- for stdin)]:file:_files -g "*.(cx|cxd)"' \
        '--target=[output target]:target:(text cx json yaml xml csv tsv mermaid svg png)' \
        '(-e --expression)'{-e,--expression}'[inline program]:program:' \
        '(-d --data-text)'{-d,--data-text}'[inline input data]:data:' \
        "${allow_flags[@]}" \
        '*:program:_files -g "*.cx"'
      ;;
    select)
      # cx select 'PATH' [FILE] — PATH is a CXPath expression (typed, not
      # completed); the optional second positional is the input document.
      _arguments \
        '1:cxpath expression:' \
        '2:file:_files -g "*.(cx|cxd)"'
      ;;
    diagram)
      _arguments \
        '--format=[diagram format]:format:(mermaid svg png)' \
        '-o[output file (recommended for svg/png)]:file:_files' \
        '--allow-subprocess[grant the subprocess capability (required by svg/png)]' \
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
    store-serve)
      _arguments \
        '--config=[service config (cxstore.service.cx)]:file:_files -g "*.cx"' \
        '--exit-on-stdin-eof[drain gracefully when stdin reaches EOF (spawner tether)]' \
        "${allow_flags[@]}"
      ;;
    store-health)
      _arguments \
        '--url=[ready-probe URL of the running daemon]:url:'
      ;;
    fabric-serve)
      _arguments \
        '--config=[fabric service config]:file:_files -g "*.cx"' \
        '--exit-on-stdin-eof[drain gracefully when stdin reaches EOF (spawner tether)]' \
        "${allow_flags[@]}"
      ;;
    store-rotate-kek)
      _arguments \
        '--url=[store URL]:url:' \
        '--encrypt-key-id=[current KEK id]:key-id:' \
        '--new-key-id=[replacement KEK id]:key-id:'
      ;;
    lsp)
      _arguments \
        '--verbose[trace incoming methods on stderr]'
      ;;
    *)
      _files -g '*.(cx|cxd|cxs|xml|json|yaml|yml|toml|md|csv|tsv|psv|arrow|parquet)'
      ;;
  esac
}

_cx "$@"
