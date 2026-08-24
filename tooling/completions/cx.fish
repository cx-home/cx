# cx CLI fish completion.
# Install: place at ~/.config/fish/completions/cx.fish
#
# Kept in lockstep with the dispatch table in vcx/cmd/main.v —
# `make check-completions-drift` fails if a subcommand is missing here.

# Subcommands (`select` is the CXPath query subcommand, #462 / cli.md §3.8:
# `cx select 'PATH' [FILE]`, flagless; `diagram`
# renders the program as a diagram, `code-diagram`/`code-tree` render the
# program AST, `lock` manages the dependency lockfile, `store-*` are the
# CSRP store-service verbs).
complete -c cx -f -n '__fish_use_subcommand' -a fmt -d 'Format CX text canonically'
complete -c cx -f -n '__fish_use_subcommand' -a canonical -d 'Strict canonical form'
complete -c cx -f -n '__fish_use_subcommand' -a hash -d 'SHA-256 of canonical bytes'
complete -c cx -f -n '__fish_use_subcommand' -a eq -d 'Compare two files'
complete -c cx -f -n '__fish_use_subcommand' -a diff -d 'Semantic diff'
complete -c cx -f -n '__fish_use_subcommand' -a lint -d 'Lint a CX file'
complete -c cx -f -n '__fish_use_subcommand' -a schema -d 'Schema verb family — infer an open-mode .cxs from a corpus'
complete -c cx -f -n '__fish_use_subcommand' -a tools -d 'Agent-tool verb family — project command defs to MCP tool descriptors'
complete -c cx -f -n '__fish_use_subcommand' -a validate -d 'Validate against schema'
complete -c cx -f -n '__fish_use_subcommand' -a table -d 'Table operations'
complete -c cx -f -n '__fish_use_subcommand' -a demo -d 'Run the cx demo'
complete -c cx -f -n '__fish_use_subcommand' -a xap -d 'XAP project tooling — cx xap init NAME scaffolds one'
complete -c cx -f -n '__fish_use_subcommand' -a scaffold -d 'Scaffold a typed CX skeleton'
complete -c cx -f -n '__fish_use_subcommand' -a eval -d 'Evaluate a CX program'
complete -c cx -f -n '__fish_use_subcommand' -a primer -d 'Print the LLM onboarding primer for this binary'
complete -c cx -f -n '__fish_use_subcommand' -a version -d 'Version / build info (same as -v/--version)'
complete -c cx -f -n '__fish_use_subcommand' -a select -d 'CXPath query over a document'
complete -c cx -f -n '__fish_use_subcommand' -a diagram -d 'Render a CX program as a diagram'
complete -c cx -f -n '__fish_use_subcommand' -a code-diagram -d 'Render program AST to a Mermaid diagram'
complete -c cx -f -n '__fish_use_subcommand' -a code-tree -d 'Render program AST as an indented tree'
complete -c cx -f -n '__fish_use_subcommand' -a lock -d 'Manage the dependency lockfile'
complete -c cx -f -n '__fish_use_subcommand' -a store-serve -d 'Run the CSRP store-service daemon'
complete -c cx -f -n '__fish_use_subcommand' -a store-health -d 'Readiness probe for the store service'
complete -c cx -f -n '__fish_use_subcommand' -a store-rotate-kek -d 'Rotate the store key-encryption key'
complete -c cx -f -n '__fish_use_subcommand' -a fabric-serve -d 'Run the fabric event-stream daemon'
complete -c cx -f -n '__fish_use_subcommand' -a lsp -d 'Run cx Language Server over stdio'

# Top-level (no subcommand) conversion / evaluation flags — vcx/cmd/main.v.
complete -c cx -f -n '__fish_use_subcommand' -l ast -d 'dump the parsed AST'
complete -c cx -f -n '__fish_use_subcommand' -l cx -d 'emit canonical CX'
complete -c cx -f -n '__fish_use_subcommand' -l xml -d 'emit XML'
complete -c cx -f -n '__fish_use_subcommand' -l json -d 'emit JSON'
complete -c cx -f -n '__fish_use_subcommand' -l yaml -d 'emit YAML'
complete -c cx -f -n '__fish_use_subcommand' -l toml -d 'emit TOML'
complete -c cx -f -n '__fish_use_subcommand' -l md -d 'emit Markdown'
complete -c cx -f -n '__fish_use_subcommand' -l csv -d 'emit CSV'
complete -c cx -f -n '__fish_use_subcommand' -l tsv -d 'emit TSV'
complete -c cx -f -n '__fish_use_subcommand' -l psv -d 'emit PSV'
complete -c cx -f -n '__fish_use_subcommand' -l cxcol -d 'emit columnar CX'
complete -c cx -f -n '__fish_use_subcommand' -l compact -d 'compact output'
complete -c cx -f -n '__fish_use_subcommand' -l lossless -d 'typed XML for exact round-trip'
complete -c cx -f -n '__fish_use_subcommand' -l from -a 'cx xml json yaml toml md' -d 'input format (convert pipeline)'
complete -c cx -f -n '__fish_use_subcommand' -l to -a 'cx xml json yaml toml md csv tsv psv' -d 'output format'
complete -c cx -f -n '__fish_use_subcommand' -l include-root -r -d 'resolve [?cx include] against this root'
complete -c cx -f -n '__fish_use_subcommand' -l data -r -d 'separate data input, bound as $doc (- for stdin)'
complete -c cx -f -n '__fish_use_subcommand' -s e -l expression -r -d 'inline program expression'
complete -c cx -f -n '__fish_use_subcommand' -s v -l version -d 'print version'

# Capability grants (security.md §3) — top-level program reading + eval + store-serve + fabric-serve.
for sub in '__fish_use_subcommand' '__fish_seen_subcommand_from eval' '__fish_seen_subcommand_from store-serve' '__fish_seen_subcommand_from fabric-serve'
    complete -c cx -f -n "$sub" -l allow-all -d 'grant all capabilities'
    complete -c cx -f -n "$sub" -l allow-read -d 'grant filesystem read'
    complete -c cx -f -n "$sub" -l allow-write -d 'grant filesystem write'
    complete -c cx -f -n "$sub" -l allow-net -d 'grant network access (optionally =host:port)'
    complete -c cx -f -n "$sub" -l allow-env -d 'grant environment access'
    complete -c cx -f -n "$sub" -l allow-clock -d 'grant clock access'
    complete -c cx -f -n "$sub" -l allow-random -d 'grant randomness'
    complete -c cx -f -n "$sub" -l allow-subprocess -d 'grant subprocess spawning'
    complete -c cx -f -n "$sub" -l allow-eval -d 'grant dynamic eval'
    complete -c cx -f -n "$sub" -l allow-secret-reveal -d 'grant secret reveal'
end

# fmt flags
complete -c cx -n '__fish_seen_subcommand_from fmt' -s w -d 'write changed files in place'
complete -c cx -n '__fish_seen_subcommand_from fmt' -l migrate-predicates -d 'predicate-surface cutover sweep'
complete -c cx -n '__fish_seen_subcommand_from fmt' -l collapse-lets -d 'collapse cascading let idioms'

# diff flags
complete -c cx -n '__fish_seen_subcommand_from diff' -l format -a 'unified json summary' -d 'output format'
complete -c cx -n '__fish_seen_subcommand_from diff' -l no-color -d 'disable color output'
complete -c cx -n '__fish_seen_subcommand_from diff' -l color -a 'auto always never' -d 'color output'

# lint flags
complete -c cx -n '__fish_seen_subcommand_from lint' -l format -a 'text json summary' -d 'output format'
complete -c cx -n '__fish_seen_subcommand_from lint' -l fail-on -a 'info warn error none' -d 'exit-1 severity threshold'
complete -c cx -n '__fish_seen_subcommand_from lint' -l disable -r -d 'comma-separated rule IDs to disable'
complete -c cx -n '__fish_seen_subcommand_from lint' -l only -r -d 'run only this rule ID'
complete -c cx -n '__fish_seen_subcommand_from lint' -l config -r -d 'explicit .cxlint.cx path'
complete -c cx -n '__fish_seen_subcommand_from lint' -l no-config -d 'skip .cxlint.cx discovery'

# validate flags
complete -c cx -n '__fish_seen_subcommand_from validate' -l schema -r -d 'schema file (.cxs)'
complete -c cx -n '__fish_seen_subcommand_from validate' -l fail-on -a 'info warn error none' -d 'exit-1 severity threshold'
complete -c cx -n '__fish_seen_subcommand_from validate' -l mode -a 'open strict closed' -d 'schema mode override'
complete -c cx -n '__fish_seen_subcommand_from validate' -l apply-defaults -d 'apply schema defaults'

# schema verbs + flags
complete -c cx -f -n '__fish_seen_subcommand_from schema' -a 'infer'
complete -c cx -f -n '__fish_seen_subcommand_from tools' -a 'export'
complete -c cx -n '__fish_seen_subcommand_from tools' -l output -d 'write the tools array to a file'
complete -c cx -n '__fish_seen_subcommand_from schema' -l sample -d 'bound the corpus to the first N documents'
complete -c cx -n '__fish_seen_subcommand_from schema' -l output -d 'write the schema to a file'

# table verbs + flags
complete -c cx -f -n '__fish_seen_subcommand_from table' -a 'info dump load'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l to -a 'cx parquet arrow' -d 'output format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l from -a 'cx parquet arrow' -d 'input format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l output -r -d 'output file'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l strict -d 'strict column typing'

# scaffold kinds
complete -c cx -f -n '__fish_seen_subcommand_from scaffold' -a 'config data doc log table'

# eval flags
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l data -r -d 'input CX file (- for stdin)'
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l target -a 'text cx json yaml xml csv tsv mermaid svg png' -d 'output target'
complete -c cx -f -n '__fish_seen_subcommand_from eval' -s e -l expression -r -d 'inline program'
complete -c cx -f -n '__fish_seen_subcommand_from eval' -s d -l data-text -r -d 'inline input data'

# select — cx select 'PATH' [FILE]: flagless; PATH is a CXPath expression
# (typed, not completed), the optional second positional is the document.
complete -c cx -n '__fish_seen_subcommand_from select' -F

# diagram flags (vcx/cmd/diagram.v: --format=mermaid|svg|png + -o
# + --allow-subprocess, which svg/png require)
complete -c cx -f -n '__fish_seen_subcommand_from diagram' -l format -a 'mermaid svg png' -d 'diagram format'
complete -c cx -n '__fish_seen_subcommand_from diagram' -s o -r -d 'output file (recommended for svg/png)'
complete -c cx -f -n '__fish_seen_subcommand_from diagram' -l allow-subprocess -d 'grant the subprocess capability (required by svg/png)'

# code-diagram flags
complete -c cx -f -n '__fish_seen_subcommand_from code-diagram' -l level -a 'min compact full' -d 'detail level'

# lock flags
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l check -d 'verify the lockfile is up to date'
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l update -d 'regenerate the lockfile'
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l output -r -d 'lockfile path'

# store-serve flags (capability grants added above)
complete -c cx -n '__fish_seen_subcommand_from store-serve' -l config -r -d 'service config (cxstore.service.cx)'
complete -c cx -f -n '__fish_seen_subcommand_from store-serve' -l exit-on-stdin-eof -d 'drain gracefully on stdin EOF (spawner tether)'

# fabric-serve flags (capability grants added above)
complete -c cx -n '__fish_seen_subcommand_from fabric-serve' -l config -r -d 'fabric service config'
complete -c cx -f -n '__fish_seen_subcommand_from fabric-serve' -l exit-on-stdin-eof -d 'drain gracefully on stdin EOF (spawner tether)'

# store-health flags
complete -c cx -f -n '__fish_seen_subcommand_from store-health' -l url -r -d 'ready-probe URL'


# store-rotate-kek flags
complete -c cx -f -n '__fish_seen_subcommand_from store-rotate-kek' -l url -r -d 'store URL'
complete -c cx -f -n '__fish_seen_subcommand_from store-rotate-kek' -l encrypt-key-id -r -d 'current KEK id'
complete -c cx -f -n '__fish_seen_subcommand_from store-rotate-kek' -l new-key-id -r -d 'replacement KEK id'

# lsp flags
complete -c cx -f -n '__fish_seen_subcommand_from lsp' -l verbose -d 'trace methods on stderr'

# Default: complete CX-family files (.cx / .cxd / .cxs) + convertible formats
complete -c cx -F
