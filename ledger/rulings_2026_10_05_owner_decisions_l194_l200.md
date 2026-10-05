# Owner decisions 2026-10-05 ~01:5xZ — Letters 194 to 200: no budget pause, `[?let]` destructures, one `[order-by]` clause stands, a path call head stays refused, sequences and arrays become keys, a pattern's child position binds the child, atoms stay no key kind

**Status: RULED (owner, 2026-10-05 ~01:4xZ–02:0xZ, in session, on the integrator's letters as numbered on #1591 and re-explained with examples at the owner's word "make sure you are giving the very best recommendation long term for cx"; recorded by the integrator the same hour). GAPS-1, OVER-1, OVER-2, RSIZE-1, FE-2, FE-5, ORDK-1, SETB-1, 1173-b, 1172-Q1a, EN-4, RS-38, AGENTS.md rule 1.**

## The owner's words, verbatim

"194b" — "195a" — "196a" — "197a" — "198a" — "199a" — "200b" (195–200 after "give me better explanations and examples and make sure you are giving the very best recommendation long term for cx").

## NOPAU-1 — no budget pause: running agents finish into extra usage rather than pay a resume (Letter 194 = (b))

The 90 % PAUSE of the window is retired: an agent mid-work runs to "every commit pushed, the pipeline run started" into extra usage (OVER-1's slush, OVER-2's tens of dollars), because a resume costs ~150k tokens per agent for no code change (seven on 2026-10-04, ~1 M). Launch pacing stands (a wave at a window's start; nothing launches past the taper); the owner reads the extra-usage line on the board.

## LETD-1 — `[= PATTERN value]` destructures in `[?let]` as the single-arm `[?match]` does; a shape that does not fit is a loud refusal (Letter 195 = (a); #1810 §6; the earlier let-binding decision reversed on this one point)

`[?let [= [$a, $b] $pair] …]` binds `$a` and `$b`; a miss is the language's NO_MATCH refusal through the same err channel `[?let]` already propagates a computed value's err. One rule for the binding form in `[?for]`, `[?let]` and `[?match]`. The case `program-gap-156-…`'s `[?let]` half goes green; code.md's `[?let]` sentence moves with it (RS-38). Rejected: (b) `[?let]` kept total (two rules for one form).

## Letter 196 = (a) — the 10-02 order-by decision stands: one `[order-by]` clause carries every key in order; a second clause is refused by name

No new id. The letter's case moves to the one-clause form `[order-by $u/@age desc $u/@name asc]`. Rejected: (b) several clauses with the first primary (two spellings; the clause order silently decides the primary key — the pin read the last as primary).

## Letter 197 = (a) — the call-head decision stands: a call head is a declared callable, never a path

No new id. `[$ops.$op 2 3]` stays refused; the spelling is `[?let [= $f $ops.$op] [$f 2 3]]`; the letter's case moves to it. Rejected: (b) reversing FE-5 (the measured op-table tax).

## CKEY-1 — a sequence or an array is a set member and a map key: Ring 0 admits compound keys (Letter 198 = (a); #1809 §10; the scalar-key decisions amended)

A value with a canonical form and a hash is a sound key: `{(3, 4): :visited}` and a set of pairs read, canonicalize, hash and compare by identity; the JSON projection refuses a non-string key by name (as it refuses an `[err]` at the boundary), never encodes it silently; `map:get`, `set:of` and the pattern forms take the compound key. One data round (cx-core-data: reader, canonical form, hash, cxdm §2.6's key kinds; cx-core-code: the map and set verbs), the letter's case green. Rejected: (b) scalar keys only, ports mangling `"3,4"` (the silently-wrong class); (c) a second set kind.

## PCHLD-1 — a child position in an element pattern binds the child, always (Letter 199 = (a); #1809 §18; the one-child binding decision reversed)

`[?match [ok [val 1]] [case [ok $s] …]]` binds `$s` to `[val 1]`, as `[ok 5]` binds 5 — never the parent. A handler that wants the whole error binds the subject (`[case $e …]` or `[?let [= $e $v]]` before the match). Every `[err $e]` site in the libraries and corpora migrates in the round that lands this, counted in RESULTS.md (CAP1's local branch gcap1-pat 0df033f3 is the full fix). Rejected: (b) unwrapping only when the element has no attributes (a rule that depends on an accident); (c) keeping 1172-Q1a.

## Letter 200 = (b) — the key-kind decision stands: an atom is not a key kind; `[?for-map]` refuses an atom key as the literal does

No new id. The letter's case stays advisory on #1809; a port keys by `[$string :tuesday]`. Rejected: (a) atoms as a key kind (EN-4's five grounds reverse; two keys that print alike).
