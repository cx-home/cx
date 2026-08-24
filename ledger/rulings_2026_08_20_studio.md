# Rulings 2026-08-20 — the studio (W26), design letter ST ruled in full

**Owner (spec-review session): "all a" — ST-1(a) … ST-8(a)**, on the design
letter design/787/w26/studio.md (POSED same day after the owner finding: the
studio was to be POC'd in the first days of the ux campaign and completed in
full finish by v0.16.0; it was never scheduled — R1's "safely deferrable"
quietly became "never started"). Implementation runs in a dedicated
autonomous session (owner direction); THE CUT WAITS on ST-8a's acceptance,
subject to its fallback trigger.

- **ST-1a** — the studio is an EDIT MODE of the real web face: same
  projection, same emitter, plus a selection overlay + inspector. Rider:
  edit mode suspends normal app pointer interaction (selection-first).
- **ST-2a** — the emitter stamps `data-cx-sel` (resolved target: claim vs
  placed-id, plus hint provenance) beside `data-cx-frag` at render, edit
  mode only. One resolver; edit-mode goldens pin the stamped bytes.
- **ST-3a** — the vocabulary completes: `[ux:place]` (author-assigned id,
  apply-time uniqueness refusal; placeable = component names resolvable via
  the §2.3 cascade, never raw markup) and `[ux:remove]` (the addressed
  element's own subtree goes with it — P0-26 protects unaddressed SIBLINGS;
  its own clause + fixture). Both P0-26..29 semantics, journaled,
  propose/commit-capable.
- **ST-4a** — `set-hint` writes land at the SURFACE level only at v1;
  inherited hints display provenance with override-here as the one action.
- **ST-5a** — studio chrome = ONE vendored, pinned, CSP-clean asset
  (studio.js/css, edit mode only); reserved root `#cx-studio`,
  `data-cx-studio-*` namespace; never writes `hx-*` or any P0-31 attribute;
  the overlay never mutates the bytes being edited.
- **ST-6a** — gating = a `ux:edit` claim through the §6.5 claims mapping;
  the PEP rechecks every layout command server-side (§6.2 hide-vs-refuse
  applies to the toggle).
- **ST-7a** — undo = client-held INVERSE-COMMAND stack emitted through the
  journaled path. The inverse-pair table is leg-1 spec work: move↔move,
  set-hint↔set-hint(prior), place↔remove, wrap↔(move child back + remove
  empty wrapper) as a P0-27 batch.
- **ST-8a** — FULL FINISH on the web face for v0.16.0 (six acceptance
  lines in the letter §ST-8): five command handlers + refusal fixtures;
  edit mode (toggle, overlay, inspector w/ provenance, palette);
  propose/commit + undo; live re-render of every attached client on
  commit (both faces); the lens acceptance end-to-end (an editor under a
  reduced projection edits what it sees, withheld elements survive);
  drive.cx steps + fixtures, zero new htmx attributes, zero golden
  movement outside the new edit-mode fixtures.
  **Fallback trigger (ruled with 8a):** if leg 4 (studio client) slips
  past its second day, cut with legs 1–3 + selection/move/commit working,
  palette completed in the first post-cut days.

Spec edits (ux.md §4 additions, the edit-mode emitter clause, the studio
asset clause, the inverse-pair table) are LEG 1 of the implementation
session and carry tokens `RULED: ST-1` … `RULED: ST-8` as exercised.
Tracking issue filed at ruling time.
