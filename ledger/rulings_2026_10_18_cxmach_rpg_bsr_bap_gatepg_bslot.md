# Rulings 2026-10-17/18 on the port of the shell machinery to cx: five decisions

**Status: RULED (the integrator on STREAMS/state/claims.txt for RPG-1, BSR-1 and BAP-1; the owner, via the integrator, for GATEPG-1 and BSLOT-1; recorded by the cxmach stream on the integrator's order of 2026-10-18T09:09:22Z).** Each id below answers an ASK of the cxmach stream (the CXMACH-1 port of the repository's shell machinery to cx under LANG-1) or an owner ruling that stream implements. Three ids are re-spelled here so the index can parse them: an id is two to six capitals, a dash and digits (IDSH-1).

## RPG-1 — (a): the R2.2 profile gate is one cx program, scripts/r22_profile_gate.cx, and every caller runs it, the Linux container body included

`R22-1` (unparsed, IDSH-1) -> `RPG-1`. The integrator's RULING line of 2026-10-17T22:31:31Z named the decision `R22-1`, and cxmach's landing subject `fced13623` (scripts/r22_profile_gate.cx + release_profile_gate.cx …) cites it as `(RULED: R22-1 = (a))`. `R22` holds digits, outside the id grammar's two to six capitals (CFG-1), so no page can declare it and the U7 tick on 1df41dba3 read ledger-index-check red. The decision is renamed `RPG-1` (the integrator, 2026-10-18T09:09:22Z), recorded under that name here; this line is the record ledger_index.cx reads (the shape of MYCDC-1's), since a landed subject cannot be rewritten.

> RULING integrator -> cxmach 2026-10-17T22:31:31Z (a): port scripts/lib/r22_profile_gate.sh + release_profile_gate.sh to scripts/r22_profile_gate.cx and switch EVERY caller including the container body in release_linux.cx (PGL-1: one implementation); the darwin arms proven on plants vs the .sh, the container arm proven by its rendered text only, its first real run is the first Docker run after #1956 and BEFORE any cut — state that on #1956 and in the port's header; the .sh retire with the port.

Where it landed: fced13623 (the port), 250fa8928 (its reader-parity row), U7 1df41dba3. The #1956 comment is issuecomment-6246970727.

## BSR-1 — (a): the build-slot.sh retire edits the stale mentions in scripts/runner/README.md and one comment of flows/postmerge.flow.cx, text only

> RULING integrator -> cxmach 2026-10-18T07:55:58Z BSR-1 = (a): edit the stale mentions only (scripts/runner/README.md:20/25/58/77 and the comment flows/postmerge.flow.cx:38: text, no behaviour — scripts/build-slot.sh -> scripts/build_slot.cx) in the same commit as the retire on impl/cx-F-stream-cxmach-u8, for U8; the brief's ban on scripts/runner/ and postmerge.flow.cx protects the loop's behaviour, not a path in a comment — name both hunks in the U8 OFFER line so the builder and the integrator read them; (c) keeps a shell file (LANG-1), (b) costs a gap commit for text.

Where it lands: df1238bd1 (the retire) and 4d14bd2e0 (the two text hunks), U8.

## BAP-1 — (a): scripts/test_binding_api_parity.sh is ported to cx, its argument and skip paths proven by a run, the four-binding drive by its rendered text

> RULING integrator -> cxmach 2026-10-18T08:23:43Z BAP-1 = (a): port to scripts/test_binding_api_parity.cx (R22-1's shape: the argument/skip paths proven by a run, the binding drive proven by rendered text, the header naming the first real run = the first four-binding drive under the v0.19 binding milestone), move the repos.cxd row with it, retire the .sh in the same commit; (b) loses a gate the v0.19 binding work needs back, (c) keeps shell (LANG-1). test_playground_smoke first is fine.

## GATEPG-1 — (a): the stream landing gate runs the playground and site steps whenever a union touches the wasm32 backend, the playground or docs-src, and the backend equality check whenever it touches a backend

The owner's id is `GATE-PG`, which is not id-shaped (no digits); GATEPG-1 is the same decision. The owner's RULING of 2026-10-18T11:16:37Z, in the backend words of WORD-1: landing_gate.sh adds test-playground-mermaid, test-playground-primer, test-playground-wasm-traps and test-site-phone-width whenever the union touches the wasm32 backend, the playground or docs-src; the cxmach stream ports the selection, for U8. Until it lands, a union builder runs those four steps by hand after the gate and names them in READY-UNION. The same owner hour (DIVERGE-1, 11:2xZ) makes the walker == compiled == native equality check a landing-gate step whenever a union touches a backend, ported with this selection.

## BSLOT-1 — (a): scripts/build_slot.cx itself waits on the gate slots, the perf slot and an open QUIET, so every stream's build, kit and suite goes through it

The owner's id is `SLOT-1`, which the ledger already declares for a different decision (the sigil-free comma slot, Letter 153, #1576); BSLOT-1 is the build-slot decision. The owner's RULING of 2026-10-18T11:16:37Z: build_slot.cx itself waits on gate-slots / perf-slot / an open QUIET; every stream's build, kit and suite goes through it; the stream brief stops relying on agents reading claims for QUIET-2. The cxmach stream ports it, for U8, and documents the call on the stream brief's build line.

Cites: fced13623, 250fa8928, 1df41dba3, df1238bd1, 4d14bd2e0, #1956.
