# Rulings 2026-09-03 — #1233 `[*name]` alias expansion has no amplification bound

**Status: RULED (a + b) under the standing letter partition (recommendation = long-term-best), 2026-09-03; the owner may revisit. Ruling id: 1233-Q1ab.**

## The finding

`resolve_anchor_node` (vcx/cx/tooling.v) rebuilt the anchored subtree for EVERY `[*name]` reference —
cycle-guarded, never size-bounded — and since ANC-1 (2026-08-20) that pass runs before evaluation and
every lossy projection, not only at hash time. With element nesting bounded at 64 and two aliases per
level referencing the previous anchor, a few-KB document expands to 2^64 nodes. limits.md §3 said
entity-expansion bombs are "structurally absent — there is no textual expansion pass": true of entities,
false of aliases, and §4 (LIM-2) records no parse-time budget or canonical-size cap, so nothing caught it.

## Q1 — how alias expansion is bounded (RULED: a + b)

- **(a) TAKEN — share, don't rebuild.** Values are immutable (`mk_element` boxes the element; every
  in-place edit in the tree goes through a `*n.element()` COPY), so each anchor is resolved ONCE and
  every alias to it points at the same resolved subtree. The resolved AST's memory is linear in the
  distinct anchors; the byte emission still writes every occurrence, which is what an alias means.
- **(b) TAKEN — an amplification bound at resolve time.** The resolver counts the resolved nodes as it
  shares (an alias adds its anchor's memoized count) against `4096 × parsed nodes + 4096` and refuses
  with a message naming the bound and limits.md — the same posture as the parser's own node-amplification
  gate (LIM-2: "structurally bounded in §2/§3"), and consistent with LIM-2's refusal of absolute caps: the
  bound is on a quantity the caller CANNOT see (expansion), relative to one it holds (its input). A
  legitimate heavy alias use (a 100-node anchor referenced 200 times ≈ 66×) is far inside it; the
  doubling attack leaves it at depth 12.
- (c) (b) alone — rejected: leaves every alias paying a rebuild and the resolved AST amplifying in memory
  up to the bound.
- (d) neither, document the hazard — rejected: an unbounded expansion reachable from untrusted input on
  the parse ring is the class limits.md exists to remove.

## Execution notes

- tooling.v: a resolve state (anchor table, cycle stack, memo of resolved anchors with their node counts,
  running total, budget from a parse-node count taken in `resolve_anchors_doc`); `[*name]` and `*name`
  read the memo; the count check refuses `strict canonical: alias/merge expansion exceeds the amplification
  bound …`. Canonical bytes are unchanged (sharing emits the same text), so every Tier-1 address stands —
  the extraction digest is the proof.
- limits.md: a §2 row for the alias/merge amplification bound; §3's entity sentence trued to name aliases
  as bounded by that row, not structurally absent.
- Tests (anchor_resolve_test.v): an alias used many times resolves to shared subtrees (pointer-equal);
  nested double-aliasing at depth 20 refuses naming the bound in bounded time; depth 8 resolves.
