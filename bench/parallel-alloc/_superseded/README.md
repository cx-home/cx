# Superseded V-runtime patches (archived 2026-06-12)

These patches captured intermediate stages of the Architecture-E V-runtime
memory-management work (Perceus front line + vgc STW backstop + Linux port).
They are **superseded** and kept only for historical reference.

## Canonical artifacts (in the parent dir)

- **`../E-canonical.patch`** — the single source of truth for the clone's
  (`vlang-v-latest`, upstream V `a83aabb`) Architecture-E working tree. 12 files,
  including the previously-untracked `vlib/v/gen/c/perceus.v` (now carried as a
  new-file hunk). Reverse-applies clean against the clone tree. CX-free.
- **`../A7-forward-port.bundle`** — backup of the shipping fork branch
  `cx-home/v-cx-patches` (local-only; regenerated from tip after the
  conservative-mark + option-free-methods + comment-scrub commits).

The same E work is committed on the fork branch `cx-home/v-cx-patches`
(`third_party/v`); the cx-private gitlink points at its tip.

## Supersession map

| archived patch | superseded by | note |
|---|---|---|
| vgc-stw-partial-fixes.patch | E-canonical | early "vgc disproven" era |
| minimal-collector.patch | E-canonical | cp21 STW bring-up |
| bugB-spawn-arg-rooting-fix.patch | E-canonical | folded into collector |
| bugB-residual-findspan-fix.patch | E-canonical | addr_map collision fix, folded |
| vgc-span-reuse-fix.patch | E-canonical | span-reuse + stop-settle, folded |
| vgc-init-ordering-fix.patch | E-canonical | cmain.v vgc_init ordering, folded |
| vgc-collector-linux.patch | E-canonical | 10-file E capture; its 2 vgc-file hunks went stale after the conservative-mark fix |
| perceus-seam.patch | E-canonical | P1 `-d perceus` seam |
| perceus-emission.patch | E-canonical | P1 emission core |
| vgc-conservative-mark-fix.patch | E-canonical | B13 soundness fix (the 2 vgc files); folded |
| option-free-methods-fix.patch | E-canonical | option-aware free methods; folded |
| perceus.v.mirror | E-canonical | the old untracked-mirror copy of perceus.v |
