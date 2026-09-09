# RULED: 1316-c2 — (a): the invocation's own stdout (fd 1) is its ANSWER
# channel, not the filesystem; writing a line to it is gated by NO capability,
# exactly as the diagnostics channel (fd 2) already is.

Date: 2026-09-09 (ruled 2026-09-08 22:05 ET). Issue: cx-home/cx-private#1316
(Part 2, letter **c2**), spun out for implementation as
cx-home/cx-private#1369. Campaign: v0.18.0 close-out (#1354), Lane 2 (the
#1265 flow ladder). Letter drafted by the campaign worker; **ruled by the
owner + a Fable pass at 2026-09-08 22:05 ET** and posted on #1316. The
sibling record `rulings_2026_09_09_flow_activation_seq_1316c1.md` carries
`1316-c1`; `rulings_2026_09_08_flow_run_overlay_1316b.md` carries `1316-b1`,
`1316-b2`, `1316-b3`, `1316-b4` and `1316-b5`.

## The defect, at the line

A CX program has **no capability-free way to write a line to its own stdout as
it happens.** The only path is `[$io:write-line [$env:stdout] TEXT]`, and
`io-write-line` charges `write` in `security.md` §2.1's closed effect-point
table — which is a whole-filesystem grant (#1059: a resource suffix on
`--allow-write` is a usage error, not a narrowing).

Measured at `1e1552c49` against `vcx/target/cx-dev`, the program

```
[?lib 'cx-stdlib/env']
[?lib 'cx-stdlib/io']
[$io:write-line [$env:stdout] "hello from fd 1"]
```

answers

```
[err code=cx-err:CXER0271 message='E_CAP_DENIED: write capability required for
io-write-line; none granted (grant via --allow-write)']
```

and prints `hello from fd 1` only under `--allow-write`.

So every long-running CX-written CLI verb batches and prints once at the end.
The tree carries its own witness to this, in a comment beside the workaround
(`vcx/cmd/flow_serve.v:886-891`):

> The BOOT REPORT, twice over, because the two readers are different and **CX
> has no stdout write.** An operator watching a runner that has not stopped
> needs it NOW, so it goes to the log sink (stderr by default); a caller that
> gave `--for` reads the same element back […] as the process's own answer on
> stdout.

And `cx flow watch` (`RULED: 1316-b3`, read-only by construction) cannot be
live at the CLI face at all without demanding a filesystem write grant from
the one flow verb whose whole character is "performs no effect".

## The precedent already in the tree

fd 2 is **already** treated as the invocation's own channel and charges
nothing: `log_emit` (`vcx/code/stdlib_log_notd_cx_no_pack_log.v:314-331`)
reaches `eprintln` with no `cap_guard`, and `security.md` §2.1 has **no
`log-` row at all**. `env.md` §7 likewise already puts the standard stream
HANDLES in its `(none)` row, on the stated ground that the ambient process
basics "are intrinsic to the running process and are never gated".

## What is ruled

**(a).** Two parts, and the reason is one sentence: writing to one's own
stdout is the same effect as **returning a value**, which every program
already does ungated — so gating it buys no safety while blocking every
long-running verb.

1. `security.md` gains one normative sentence: the invocation's own standard
   output (fd 1) and diagnostics (fd 2) are its ANSWER and DIAGNOSTICS
   channels, not the filesystem; writing a line to either is gated by no
   capability. This is a §2 sentence, **not** a §2.1 row: §2.1 is the closed
   table of capability-**gated** primitives, and an ungated primitive has no
   row in it by construction (`test_effect_point_table_matches_spec` asserts
   that table against `capability_gated_prims()` in both directions).
2. One primitive, narrowest form: **`[$env:write-line TEXT]`** — one string,
   no handle argument, fd 1 only, charging nothing. It joins `env.md` §7's
   `(none)` row, `env_uncapped_prims` (which IS the dispatcher's own gate
   exemption list, so spec and live guard cannot drift), and group **(d)
   ambient process basics** of `impure_without_capability_exceptions()` so
   `check-effect-alignment` stays green in direction 2.
3. `cx flow watch` streams one overlay row per transition through it —
   `1316-b3` stays READ-ONLY: no timers, no effect, because a stdout line is
   not an effect under sentence 1.

### Why `env` and not a `:stdout`-only path through `io`

The ruling named `[$env:write-line TEXT]` first and left the spelling to the
implementer "if the corpus/spec prefers one". **It does, and it prefers
`env`**, on two grounds read out of the tree rather than chosen:

- `env.md` §7 already owns exactly this group and already names its members:
  "The ambient process basics (standard streams, process identity, argument
  vector, CPU count, and process exit) require no capability: they are
  intrinsic to the running process and are never gated." `stdout` is in that
  sentence. A `write-line` beside it needs no new doctrine — it is the same
  sentence, used.
- An `io` path would have to make `io-write-line`'s charge depend on **which
  handle it is given**, i.e. on a runtime value. §2.1 names exactly three
  primitives that derive their capability per call (`io-open`,
  `store-open`, `store-open-opts`) and `io-edit-file` as a fourth shape; a
  fifth would mean a reader of a program's source can no longer tell whether
  a given `[$io:write-line …]` charges `write`. Static reachability of effect
  points is load-bearing for the `pure` classifier (`security.md:28`), so
  moving this charge off the name and onto the argument would cost more than
  the primitive is worth.

**Refused, recorded on #1316:** (b) batching forever — the CLI face is never
live; (c) streaming under `--allow-write` — the observer verb becomes the one
flow verb demanding a filesystem grant.

## Scope note carried from the ruling

`1316-c2` touches `security.md`, so it is deliberately **not** #1316's and not
inside Part 2: it lands as #1369. Until it lands, `watch` stays as shipped
(the (b) holding position): batched, read-only, correct-but-not-live at the
CLI face, with the XAP face live via `1316-b4`. Commits on #1369 carry
`RULED: 1316-c2`.
