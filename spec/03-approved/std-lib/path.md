# `cx-stdlib/path` — filesystem path manipulation

```cx
[module-meta name=path tier=B status=current]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/path` sub-package.

---

## §1. Scope

`cx-stdlib/path` manipulates filesystem paths as strings — splitting, joining, normalizing, extracting components. The module operates purely on path syntax; filesystem state (stat, read, list) belongs in [`spec/std-lib/io.md`](io.md). Distinct from the CXPath value kind (see [`spec/core/code.md`](../core/code.md) §5.5).

## §2. Conceptual model

Paths are strings. POSIX-style (`/foo/bar`) and Windows-style (`C:\foo\bar`) paths are auto-detected by leading character: `/`, `./`, `../` → POSIX; drive letter + `:` or UNC `\\server\share` → Windows; mixed separators → POSIX.

Most functions are platform-agnostic and produce the same output regardless of the running OS. Platform-specific behavior (e.g. case-insensitive equality on Windows) is opt-in via explicit functions.

## §3. Public function surface

### §3.1. Component extraction

```
[?def dirname    scope=public pure [returns string]            ($p::string) ...]
[?def basename   scope=public pure [returns string]            ($p::string) ...]
[?def extension  scope=public pure [returns string]            ($p::string) ...]
[?def stem       scope=public pure [returns string]            ($p::string) ...]
[?def parent     scope=public pure [returns string]            ($p::string) ...]
[?def parts      scope=public pure [returns [sequence string]] ($p::string) ...]
```

- `dirname("/a/b/c.txt")` → `"/a/b"`.
- `basename("/a/b/c.txt")` → `"c.txt"`.
- `extension("/a/b/c.txt")` → `".txt"` (with leading dot; `""` if none).
- `stem("/a/b/c.txt")` → `"c"`.
- `parent` — alias for `dirname`.
- `parts("/a/b/c.txt")` → `["a","b","c.txt"]` (drops the leading slash).

### §3.2. Composition

```
[?def join      scope=public pure [returns string] (*$parts::string) ...]
[?def join-seq  scope=public pure [returns string] ($parts::[sequence string]) ...]
```

- `join` is variadic for the literal case: `[$join "a" "b" "c"]` → `"a/b/c"`.
- `join-seq` takes a pre-built sequence for the programmatic case (CX has no call-site spread; see [`spec/core/code.md`](../core/code.md) §12.2.4).
- Both collapse redundant separators (`"a/"` + `"/b"` → `"a/b"`).

### §3.3. Normalization

```
[?def normalize  scope=public pure   [returns string] ($p::string) ...]
[?def absolute   scope=public impure [returns string] ($p::string) ...]
[?def relative   scope=public pure   [returns string] ($from::string $to::string) ...]
[?def canonical  scope=public impure [returns string] ($p::string) ...]
```

- `normalize` — collapse `.` and `..` segments syntactically; remove redundant separators. Pure.
- `absolute` — prefix `cwd` if relative. Impure (reads `cwd`).
- `relative` — compute the relative path from `from` to `to`. Pure.
- `canonical` — resolve symlinks and normalize. Impure. Raises `CXER2600` on missing intermediate; `CXER2601` on symlink cycle.

### §3.4. Predicates

```
[?def is-absolute       scope=public pure [returns bool] ($p::string) ...]
[?def is-relative       scope=public pure [returns bool] ($p::string) ...]
[?def is-posix-style    scope=public pure [returns bool] ($p::string) ...]
[?def is-windows-style  scope=public pure [returns bool] ($p::string) ...]
[?def has-extension     scope=public pure [returns bool] ($p::string) ...]
```

All pure syntactic checks; no filesystem access.

### §3.5. Manipulation

```
[?def with-extension  scope=public pure [returns string] ($p::string $ext::string) ...]
[?def with-stem       scope=public pure [returns string] ($p::string $stem::string) ...]
[?def with-name       scope=public pure [returns string] ($p::string $name::string) ...]
[?def append          scope=public pure [returns string] ($p::string $suffix::string) ...]
```

- `with-extension("a.txt", ".md")` → `"a.md"`.
- `with-stem("a/b.txt", "c")` → `"a/c.txt"`.
- `with-name("a/b.txt", "c.md")` → `"a/c.md"`.
- `append("a/b", "/c")` → `"a/b/c"`.

### §3.6. Globbing (pure pattern match, no filesystem walk)

```
[?def match-glob  scope=public pure [returns bool] ($pattern::string $p::string) ...]
```

Purely syntactic match over `/`-split segments. No filesystem access. `io/glob` (in [`spec/std-lib/io.md`](io.md)) uses this primitive to filter walk results.

Metacharacters:

- `*` — zero or more characters within a single segment (does not cross `/`).
- `?` — exactly one character within a segment.
- `[abc]` — character class within a segment.
- `**` — zero or more whole path segments (recursive wildcard).

`**` zero-segment behavior:

- `match-glob("**/*.cx", "a/b/c.cx")` → `true`.
- `match-glob("**/*.cx", "c.cx")` → `true` (`**` matches zero segments).
- `match-glob("*.txt", "a/b.txt")` → `false` (`*` does not cross `/`).

Malformed patterns raise `CXER2602`.

### §3.7. Separators

```
[?def separator       scope=public pure [returns string] () ...]
[?def list-separator  scope=public pure [returns string] () ...]
```

- `separator` — `/` on POSIX, `\` on Windows. (Both are accepted on input by all path functions.)
- `list-separator` — `:` on POSIX, `;` on Windows (for PATH-style splitting).

### §3.8. Path-safety

```
[?def is-within             scope=public pure [returns bool]   ($dir::string $candidate::string) ...]
[?def safe-join             scope=public pure [returns string] ($base::string $untrusted::string) ...]
[?def equals-case-insensitive scope=public pure [returns bool] ($a::string $b::string) ...]
```

Defense against path-traversal in untrusted input. Both `is-within` / `safe-join` are pure and `normalize`-based; no filesystem access.

- `is-within(dir, candidate)` — true iff `candidate`, after `normalize`, stays under `dir`. A directory is within itself.
- `safe-join(base, untrusted)` — join then `normalize`; raises `CXER2603` if the result escapes `base`.
- `equals-case-insensitive` — explicit case-insensitive comparison (default `==` is case-sensitive).

## §4. Edge cases

- **Trailing separators.** `dirname("/a/b/")` → `"/a"`.
- **Empty path.** `dirname("")` → `""`; `basename("")` → `""`.
- **Root.** `dirname("/")` → `"/"`; `parts("/")` → `[]`.
- **UNC / drive paths.** `\\server\share\file` and `C:\file` are recognised; component extraction preserves the drive letter.
- **Path-safety boundary.** `is-within` / `safe-join` are syntactic (post-`normalize`); they do not resolve symlinks. For symlink-aware containment, resolve via `canonical` first.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER2600` | `E_PATH_NOT_FOUND` | `canonical` on a path with a missing intermediate component |
| `CXER2601` | `E_PATH_RESOLVE_LOOP` | `canonical` detects a symlink cycle |
| `CXER2602` | `E_PATH_INVALID_PATTERN` | `match-glob` with a malformed glob pattern |
| `CXER2603` | `E_PATH_ESCAPES_BASE` | `safe-join` when the normalized result escapes `base` |

## §6. Conformance fixtures

Under `conformance/stdlib/path.cxd`:

- Component extraction on standard POSIX and Windows paths.
- Empty / root / trailing-slash edge cases.
- Multiple extensions: `extension("a.tar.gz")` → `".gz"`; `stem` → `"a.tar"`.
- `[$join "a/" "/b/" "/c"]` → `"a/b/c"`; `join-seq(["a/","/b/","/c"])` → `"a/b/c"`.
- `normalize("a/./b/../c")` → `"a/c"`.
- `relative("/a/b","/a/c/d")` → `"../c/d"`.
- `with-extension` replaces; doesn't append.
- Glob: `*.txt` matches; `*` does not cross `/`; `**/*.cx` matches both `"c.cx"` and `"a/b/c.cx"`.
- `is-within("/srv/www","/srv/www/a/b.txt")` → `true`; `"/srv/www/../etc/passwd"` → `false`.
- `safe-join("/srv/www","a/b.txt")` → `"/srv/www/a/b.txt"`; `"../etc/passwd"` raises `CXER2603`.
- Absolute predicate distinguishes `/foo`, `./foo`, `foo`, `C:\foo`.

## §7. Cross-references

- [`spec/std-lib/io.md`](io.md) — actual filesystem operations; `io/glob` uses `match-glob`.
- [`spec/std-lib/env.md`](env.md) — `cwd`, `executable-path` return strings consumed by this module.
- [`spec/core/code.md`](../core/code.md) §5.5 — CXPath (the data-navigation path; distinct from OS paths).
