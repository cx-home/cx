# Rulings 2026-08-20 — the --client scaffold RUNS (#846 follow-through)

## ATC-2 — `cx xap init --client` produces a RUNNABLE client

**Status:** RULED (owner, 2026-08-20: **"3 fix it now"** — the say-plainly
disposition just landed under ATC-1, where `--client` emits a client SPEC +
shell and states so, is insufficient; the scaffold must RUN).

**Ruling.** A fresh `cx xap init NAME --client` scaffold serves out of the
box: the client project gains a generated `serve.cx`, and
`cx <NAME>-web-client/serve.cx` (run from the client directory, with the
grants its header states) brings up a working surface whose panes render
**generic table views derived from the surface's `shows` declarations** —
every shown field a column, no hand-authored view required — with intents
wired through the standard `POST /intent/<verb>` path. This is #846's own
design intent ("generic table views derived from the feature's `shows`
declarations") made real rather than merely disclosed.

**The floor discipline.** The generic table view is a FLOOR — the starting
point the author replaces with views in their own medium. The generated
README labels it exactly that; it is never a lesson in final UX. The
derivation is single-sourced: the scaffolder derives BOTH the surface's
`[shows …]` strings and the client's table views from one panel table in
the generator, so the two cannot drift apart.

**Mechanics ruled in under this token:**

1. *Web-medium serializer gains the `table` view node* (beside `list`,
   `control`, `text`): `[table [head [cell …]…] [row [cell …]…]…]` →
   `<table><thead>…<tbody>…`, comprehension yields flattened exactly as
   `[list …]` bodies are. The view-tree stays medium-agnostic data; the
   application/cx leg carries it unchanged (agent parity holds).
2. *`GET /<seg>` answers the panel fragment* of the component bound to
   `/<seg>` (reserved firsts — /surface /events /static /intent — keep
   priority; unknown seg stays 404). The client layer's per-pane
   hypermedia cadence (`[pane … refresh='every Ns']`, hx-get polling) was
   declared but had NO answering route — a poll 404'd silently. The route
   makes the declared contract real.
3. *The scaffold's composite pane is served, not skipped*: the generated
   serve.cx binds a deriver for `thing-of-owner/owned-thing` (run assembly
   refuses an unproduced derived noun, composition §4.2) and commits the
   join through `[$xap:derive]` — the same producer pattern the reference
   client (reference/shop-web-client/serve.cx) demonstrates.
4. *Truth-in-help follows the truth*: the ATC-1 wording ("not a runnable
   server") retires from usage/help/README/test; the scaffold now states
   the run command and the floor discipline instead.

**Spec.** `spec/03-approved/xap/xap_authoring_process.md` §7's `cx xap
init` bullet amended under `RULED: ATC-2`: the --client scaffold is
runnable as generated, generic table views derived from `shows` as the
floor.

**Gate.** vcx/tests/xap_umbrella_test.v extends the ATC-1 drift-keeper:
the scaffolded client still validates against client.cxs AND now RUNS —
spawned headless, asserted to answer HTTP with the derived table (columns
= the shown fields), the pane-refresh fragment route, and a committed
intent visible in the re-rendered table.

## ATC-2 riders resolved at integration (parent session, same day)

- (a) The reference client shell polled `/orders`/`/shipments` (plural) while
  the components bind `/order`/`/shipment` — the two panes 404'd silently on
  every cadence tick. Fixed to the bound segments (layout.html one-liner);
  the delay pane already matched.
- (d) The view-tree node vocabulary (panel/heading/list/control/text/table)
  was enumerated nowhere in xap.md — pinned in §5 under this token; additions
  are individual rulings.
- (b) recorded: derive-at-boot is the floor; live re-derive-on-commit rides
  the composition track (#865/#867). (c) the sibling-worktree test flake did
  not reproduce on the integrated tree (full xap umbrella green).
