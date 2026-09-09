# RULED: 1347-b — the program emitter's `.float_lit` renders through `cx_format_float`; §2.5's exponent-always float row STANDS

**Fable, 2026-09-09 14:55 ET, on worker A's letters (question 1), under the
owner's delegation:** `1(a)` as scoped — the spec wins, but the letter's two
premises were wrong (the exponent IS the property §2.5 names: `1.5` is
decimal's image, `1.5e0` float's, and the two kinds may never share an image or
a content address, `canonical.md:214/256`; the DATA lane was already
exponent-always through `cx_format_float`, so no data corpus moves). Refused
`1(b)` — a spec edit motivated by an implementation shortfall against a
sentence that secures the kind/address separation — and `1(c)`. Implemented by
the Fable session, 2026-09-09 evening.

## What was wrong

`program_emit.v` `.float_lit { flt_val.str() }` was the ONE renderer in the
tree that dropped the exponent. Its output re-parsed as a decimal; the shape
fingerprint saw the kind change and declined every file carrying an exponent
float — which is why nothing shipped carried the old bytes. The fingerprint
also hashed the raw token for `.float_lit`/`.decimal_lit`, so `1_000.5e0` and
`1_000.5` declined even though their emitted images were right.

## What changed

- `.float_lit` emits `cx_format_float(flt_val)` (`1.10e0` → `1.1e0`,
  `1_000.5e0` → `1.0005e3`, `100.0e0` → `1.0e2`, `-0.0e0` keeps its sign).
- `shape_src_image` hashes a float's `cx_format_float` image and a decimal's
  normalized `str_val`, under 1347-a's text-coercing exception unchanged: a
  `::string` literal keeps the raw token, and a file where the emitter would
  rewrite it fails CLOSED.
- Fixtures `fmt-038..042` (038/039/040/042 measured RED at `3ae64d274` —
  declined verbatim; 041 GUARD, fail-closed); four unit tests in
  `program_emit_head_ascription_test.v`, one asserting the formatted literal is
  still `.float_lit`.

## Not a defect (measured)

`[a n=1_000d]` is a STRING in the data reading (the Text fallback: `n='1_000d'`)
and an invalid temporal literal in the program reading — keeping its bytes was
never a §2.5 violation. No letter.

## Census / DELETES

`make fmt-sweep` before: DECLINED=93 (post-T1.9). After, measured on this
branch with the release binary: SWEEP-FILES=272 FORMATTED=174 **DECLINED=93**
UNSTABLE=0 ERROR=5 — UNCHANGED. The fifteen `.cx` files that carry an
exponent-spelled float still decline for reasons of their own (the layout
limits T1.9's ledger names, or a data-position float the data lane already
copies verbatim), so the ratchet is NOT lowered — there is nothing to lower,
and saying so beats a ratchet edit that implies a win. The class is fixed by
the five fixtures; it un-declines nothing that ships today. DELETES: the
`.float_lit`/`.decimal_lit` exclusion beside the half-1 fingerprint fix; the
declines of exponent-float program files. Nothing in `canonical.md`.
