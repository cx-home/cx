# v0.8.0: cx CLI fish completion.
# Install: place at ~/.config/fish/completions/cx.fish

# Subcommands (v0.8.0: `select` retired — CXPath is a first-class value
# kind per code.md §5.5, use `cx eval //path`; `diagram` renders a data
# diagram, `code-diagram`/`code-tree` render the program AST, `lock`
# manages the dependency lockfile).
complete -c cx -f -n '__fish_use_subcommand' -a fmt -d 'Format CX text canonically'
complete -c cx -f -n '__fish_use_subcommand' -a canonical -d 'Strict canonical form'
complete -c cx -f -n '__fish_use_subcommand' -a hash -d 'SHA-256 of canonical bytes'
complete -c cx -f -n '__fish_use_subcommand' -a eq -d 'Compare two files'
complete -c cx -f -n '__fish_use_subcommand' -a diff -d 'Semantic diff'
complete -c cx -f -n '__fish_use_subcommand' -a lint -d 'Lint a CX file'
complete -c cx -f -n '__fish_use_subcommand' -a validate -d 'Validate against schema'
complete -c cx -f -n '__fish_use_subcommand' -a table -d 'Table operations'
complete -c cx -f -n '__fish_use_subcommand' -a demo -d 'Run v0.8.0 demo'
complete -c cx -f -n '__fish_use_subcommand' -a scaffold -d 'Scaffold new project'
complete -c cx -f -n '__fish_use_subcommand' -a eval -d 'Evaluate a CX program'
complete -c cx -f -n '__fish_use_subcommand' -a diagram -d 'Render a diagram from a CX source'
complete -c cx -f -n '__fish_use_subcommand' -a code-diagram -d 'Render program AST to a Mermaid diagram'
complete -c cx -f -n '__fish_use_subcommand' -a code-tree -d 'Render program AST as an indented tree'
complete -c cx -f -n '__fish_use_subcommand' -a lock -d 'Manage the dependency lockfile'
complete -c cx -f -n '__fish_use_subcommand' -a lsp -d 'Run cx Language Server over stdio'

# table verbs
complete -c cx -f -n '__fish_seen_subcommand_from table' -a 'info dump load'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l to -a 'cx parquet arrow' -d 'output format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l from -a 'cx parquet arrow' -d 'input format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l output -r -d 'output file'

# eval flags
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l data -r -d 'input CX file (- for stdin)'
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l target -a 'text cx json yaml xml csv tsv' -d 'output target'

# diagram flags (v0.8.0)
complete -c cx -f -n '__fish_seen_subcommand_from diagram' -l format -a 'mermaid graphviz' -d 'diagram format'
complete -c cx -f -n '__fish_seen_subcommand_from diagram' -l output -r -d 'output file'
complete -c cx -f -n '__fish_seen_subcommand_from diagram' -l depth -d 'max depth'

# code-diagram flags
complete -c cx -f -n '__fish_seen_subcommand_from code-diagram' -l level -a 'min compact full' -d 'detail level'

# lock flags
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l check -d 'verify the lockfile is up to date'
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l update -d 'regenerate the lockfile'
complete -c cx -f -n '__fish_seen_subcommand_from lock' -l output -r -d 'lockfile path'

# lsp flags
complete -c cx -f -n '__fish_seen_subcommand_from lsp' -l verbose -d 'trace methods on stderr'
complete -c cx -f -n '__fish_seen_subcommand_from lsp' -l help -d 'show usage'

# Default: complete CX-family files
complete -c cx -F
