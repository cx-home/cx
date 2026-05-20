# Q7 v0.7.0: cx CLI fish completion.
# Install: place at ~/.config/fish/completions/cx.fish

# Subcommands
complete -c cx -f -n '__fish_use_subcommand' -a fmt -d 'Format CX text canonically'
complete -c cx -f -n '__fish_use_subcommand' -a canonical -d 'Strict canonical form'
complete -c cx -f -n '__fish_use_subcommand' -a hash -d 'SHA-256 of canonical bytes'
complete -c cx -f -n '__fish_use_subcommand' -a eq -d 'Compare two files'
complete -c cx -f -n '__fish_use_subcommand' -a diff -d 'Semantic diff'
complete -c cx -f -n '__fish_use_subcommand' -a lint -d 'Lint a CX file'
complete -c cx -f -n '__fish_use_subcommand' -a validate -d 'Validate against schema'
complete -c cx -f -n '__fish_use_subcommand' -a table -d 'Table operations'
complete -c cx -f -n '__fish_use_subcommand' -a demo -d 'Run v0.7.0 demo'
complete -c cx -f -n '__fish_use_subcommand' -a scaffold -d 'Scaffold new project'
complete -c cx -f -n '__fish_use_subcommand' -a eval -d 'Evaluate a template'
complete -c cx -f -n '__fish_use_subcommand' -a select -d 'Run CXPath query'
complete -c cx -f -n '__fish_use_subcommand' -a upgrade-config -d 'Migrate v0.6.0 → v0.7.0'
complete -c cx -f -n '__fish_use_subcommand' -a lsp -d 'Run cx Language Server over stdio'

# table verbs
complete -c cx -f -n '__fish_seen_subcommand_from table' -a 'info dump load'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l to -a 'cx parquet arrow' -d 'output format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l from -a 'cx parquet arrow' -d 'input format'
complete -c cx -f -n '__fish_seen_subcommand_from table' -l output -r -d 'output file'

# upgrade-config flags
complete -c cx -f -n '__fish_seen_subcommand_from upgrade-config' -l dry-run -d 'preview changes'
complete -c cx -f -n '__fish_seen_subcommand_from upgrade-config' -l lint-ref-elements -d 'scan for M7'
complete -c cx -f -n '__fish_seen_subcommand_from upgrade-config' -l help -d 'show usage'

# eval flags
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l input -r -d 'input CX file'
complete -c cx -f -n '__fish_seen_subcommand_from eval' -l target -a 'text html cx markdown json yaml xml csv tsv' -d 'output target'

# lsp flags
complete -c cx -f -n '__fish_seen_subcommand_from lsp' -l verbose -d 'trace methods on stderr'
complete -c cx -f -n '__fish_seen_subcommand_from lsp' -l help -d 'show usage'

# Default: complete CX-family files
complete -c cx -F
