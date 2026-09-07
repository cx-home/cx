# Ruling record — #1320 wave 2 (interior comments) and #1319 (the text-run 2-cycle), 2026-09-07

Decided under the owner's standing rule of 2026-09-07: a campaign does not stop
mid-wave for a question; anything foreseeable goes to campaign start, anything
else is decided on what is best for CX long-term and RECORDED. Wave 2 of the bug
campaign.

**Ordering, stated honestly:** #1319's mechanism was only established by
measurement DURING the wave, so this record is written after the fix rather than
before it (R5.0 late record). #1320 wave 2 needed no new ruling — 1320-B named
its own condition for moving the boundary, and that condition is now met.

## 1320-B's boundary moves, exactly on the condition it named

1320-B declined every file carrying an INTERIOR comment, and gave the reason:
"a form's canonical text is a SINGLE LINE and an interior comment has no line to
sit on... The remaining 103 need the width-bounded layout (#1058 T1.2) first,
because a form broken across lines is what gives an interior comment somewhere
to go." That layout landed at `ec7248861`, so the boundary moves without a new
ruling. The GUARANTEE does not move: an unplaceable comment still keeps the
whole file unchanged.

## RULED 1320-W2 — placement is decided by the comment's WRITTEN bracket depth

A comment is emitted at a break site only when `ProgramComment.depth` — the
open-bracket nesting the lexer recorded it at — equals the nesting of that site.

**This is the ruling because the obvious alternatives are unsound, and one of
them shipped in my first cut.** Placing a comment by SOURCE OFFSET alone moves
it out of the form it annotates: a comment before an inner form's closer is
after the last descendant's start offset, and node spans carry no source END, so
an offset test cannot tell "between these two children" from "inside the
previous child". Measured: `[$f 'a'  # inner\n]]  $x]` emitted
`[$f 'a']]  # inner`, relocating the comment across two bracket levels.

**And every existing verification passed while it did.** The comment inventory
matched (same texts, same order), the canonical text matched, the shape matched
— because none of the three can see WHAT a comment annotates. That is why the
discriminator has to be structural and recorded at lex time. 1320-B already
stated the principle for the trailing case ("promoting it to a standalone line
above the NEXT form would silently re-point it"); this extends the same
principle to depth.

Consequences kept deliberately fail-closed: a comment interior to a LEAF (no
break site exists inside an atom), a comment inside a `[?def]`'s VERBATIM clause
region (1318-A copies those bytes and the layout must not reach into them), a
comment before a form's closer, and a form whose source position is unknown all
return none and leave the file untouched.

Measured over the 259-file corpus: files `cx fmt` changes 122 -> 150, comment
loss 0, non-idempotent 0, errors unchanged. Not all ~87-103 interior-comment
files: the remainder are the fail-closed classes above, and that number is
reported rather than rounded up.

## RULED 1319-A — the document-level string scalar uses the TEXT predicate

`cx_emit_node`'s `.scalar_node` arm rendered a string through `cx_scalar`, whose
`.string_kind` arm returns the value RAW. So a string carrying a newline emitted
BARE and re-read as a TEXT run; the `.text_node` arm then quoted it (LF is a
control byte — §2.4 / I1 L15) and it re-read as a string scalar again. A stable
2-cycle, forever, violating `formatting.md` §7.

Ruled: that arm goes through `cx_quote_text_if_needed`, the SAME predicate the
`.text_node` arm uses. One predicate, both positions.

**This is not a new rule — it is a rule this file already states and already
applies one level down.** `cx_emit_body`'s string-scalar arm carries the comment
"this is in fact the arm that reproduced the non-idempotency; the two must agree
or they oscillate against each other", and routes through `cx_body_text_run` ->
`cx_quote_text_if_needed`. Document level never got the same treatment. The
#1318 family's thesis (one grammar, one reader; one form, one writer) applied
one arm further.

Rejected: exempt LF from `cx_text_needs_quote` so a text run stays bare. It
would also converge, and it is WRONG in the other direction — every other
control byte (NUL, CR, tab) would then emit raw, and §2.4's escape pass exists
to make control characters visible in the canonical bytes.
Rejected: leave it and rely on #1330's idempotence guard. That guard CONTAINS
the defect by declining the file, which is why `cx fmt` was a permanent no-op on
it; containment is not a cure, and the record for #1330 says so.

Note on `formatting.md` §1: quoting a text run does re-read as a string scalar,
so the node KIND changes once on first format. That is pre-existing and
identical to the already-shipped body-position behaviour, and the §1 purity
check `conformance/fmt.cxd` enforces (`cx_text_canonical` before vs after) is
satisfied. Making Text and Scalar each round-trip to their own kind is a
separate, larger question about the data reading and is NOT decided here.

Measured: the 10-byte repro `one\ntwo` is now a fixed point (`'one\ntwo'` on
every pass), and `spec/03-approved/xap/_notes/mesh-strategy.capture.cx` — the
file this issue was filed on — converges at 2924 bytes and `cx fmt` now FORMATS
it (2992 -> 2924) instead of declining, idempotently.

## Method note worth keeping

#1319's own repro was 103 bytes and this file's memory recorded "every
hand-written simplification CONVERGES, so the trigger is an unisolated
interaction". Both were wrong. The trigger is a document-level text run followed
by an element — TEN bytes. The earlier session was defeated by the absence of an
ORACLE: it judged candidates with `cx fmt`, which DECLINES this file (#1330), so
every probe looked convergent when it was being refused. `--from=cx --to=cx`
drives `emit_cx` directly with no idempotence guard in the way, and against that
oracle a greedy reducer went 2992 -> 441 bytes in two passes and hand candidates
settled the trigger in one command.
