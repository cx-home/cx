# 02 — Log parser

## What it does

Read 3 log lines, classify each by severity (INFO / WARN / ERROR),
and emit a sequence of `[entry :level :LEVEL :msg "..."]` elements.

The "ideal" version would *split* each line on whitespace and bind
the timestamp / level / message as separate fields, producing
`[entry :ts "2026-05-26 10:00:00" :level :info :msg "app starting"]`.
That version is currently impossible — see "Open gap log."

## Idiomatic shape in other languages

- **Python**: `[{"ts": ts, "level": lvl, "msg": rest} for line in lines for (ts, _, lvl, *rest) in [line.split(maxsplit=3)]]`
- **jq**: `split(" ") | {ts: (.[0]+" "+.[1]), level: .[2], msg: (.[3:]|join(" "))}`
- **AWK**: `{ printf "%s %s | %s | %s\n", $1, $2, $3, $0 }`

## Actual run

Program:

```
[?let $lines = (
  "2026-05-26 10:00:00 INFO  app starting",
  "2026-05-26 10:00:01 WARN  config file missing",
  "2026-05-26 10:00:02 ERROR fatal"
) :in
  [?for $line :in $lines :yield
    [?match true
      :when contains($line, "ERROR") :yield [entry :level :error :msg $line]
      :when contains($line, "WARN")  :yield [entry :level :warn  :msg $line]
      :when contains($line, "INFO")  :yield [entry :level :info  :msg $line]
      :else :yield [entry :level :unknown :msg $line]]]]
```

Run: `devbox run -- ./vcx/target/cx eval corpus/rosetta/02-log-parser.cx`

Observed output:

```
[entry :level :info :msg "2026-05-26 10:00:00 INFO  app starting"]
[entry :level :warn :msg "2026-05-26 10:00:01 WARN  config file missing"]
[entry :level :error :msg "2026-05-26 10:00:02 ERROR fatal"]
```

**Status:** WORKAROUND. Classification by `contains()` lets the program
report a level, but the message field still carries the whole raw line
because string-splitting is unavailable. A "real" log parser would
have the timestamp, level, and message as distinct attributes — that
shape is BLOCKED on the missing string-ops surface.

## Workarounds used

| Idiomatic | Used | Reason |
|---|---|---|
| `split($line, " ")` to break into tokens | `contains($line, "ERROR")` to classify only | No `split` / `tokenize` builtin exists; string regex / split / format gap confirmed |
| Bind timestamp as `substring($line, 0, 19)` | (skipped — substring works but only by hard-coded offsets) | `substring()` exists as XPath call but using it pre-supposes a regex/anchor surface we don't have |
| `[contains $line "ERROR"]` directive form | Used XPath form `contains($line, "ERROR")` | `contains` is XPath-call-only; the directive form returns the literal element (same bug as `floor`) |
| `:case [entry :level $l] :yield ...` pattern destructure | (not attempted here) | The match is on a *string*, not a structured shape — destructuring isn't relevant for this stage |

## Open gap log

Surface-completeness hypothesis confirmations:

1. **String ops beyond basics missing — `split` / `tokenize` / `format` / interpolation.** Listed in 0045 §"Confidence-ranked gap inventory" as "Very high" confidence (hypothesis #34 in the task brief). Confirmed here: no way to split a log line into timestamp / level / message. RE2 shim is built (per memory `project_v_re2_gap` and `vcx/Makefile` `LIB_RE2`) but not exposed in the code surface. **Files a NEW ADR (string-ops surface).**

2. **Atom-as-attribute-value syntax — `[entry :level :info]` vs `[entry level=info]`.** Discovered while writing the program. `[entry level=:info]` parse-fails (atom can't be an attribute value); `[entry :level :info]` works but uses keyword-modifier shape rather than the conventional `name=value` attribute pair. This is consistent with §3.5 of `spec/code.md` (atoms are values, attribute values are scalars/strings), but the surface friction is real. **Probably closed by spec — but worth noting.**

3. **`contains` (and friends `starts-with`, `ends-with`) are XPath-call-only.** Same gap as `floor` / `ceiling` / `round` in program #01. Filed there. Re-confirmed here on string-typed input.
