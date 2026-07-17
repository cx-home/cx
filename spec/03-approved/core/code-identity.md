# Tier-2 Code Identity

**Status:** Approved. Normative definition of Tier-2 (code) identity, the
additional content-addressed identity for CX code reserved by
[`canonical.md §1.4`](canonical.md). Tier-1 (data) identity is the strict
canonical hash (`canonical.md §1.2/§1.4`); Tier-2 is an **additional** identity
computed only in an opt-in code namespace and is **never** conflated with Tier-1.

## 1 — What Tier-2 identifies

A **definition** (`[?def NAME …]`, parsed to an ordered parameter list and a body
that parses to a program AST). Tier-2 identity is the hash of the definition's
**normalized AST** `N(def)`, computed so that two definitions collide iff they are
the same computation up to:

(a) bound-variable renaming, (b) comments / formatting, and (c) the definition's
own name.

Names are aliases, so the **name is excluded from identity** —
`[?def foo ($x) [+ $x 1]]` and `[?def bar ($y) [+ $y 1]]` share a Tier-2 hash.

## 2 — `N(def)`: the normalization

`N` produces a canonical text rendering of an alpha-normalized copy of the
definition's AST, then takes its SHA-256. `Tier-2 hash = SHA-256(N(def))`,
lowercase hex, 256-bit (matching the store hash width).

1. **Comments / formatting are structurally excluded.** The program AST carries no
   comment node and no layout; parsing discards both. Comment/format insensitivity
   is therefore structural, not a separate pass.

2. **Alpha-normalize binders to de Bruijn levels.** Walk the AST with a scope
   stack. Each **binder** introduces names assigned sequential **de Bruijn levels**
   (the outermost binder is level 0, incremented as binders are entered in
   left-to-right, outer-to-inner order). Every **read** of a bound local is
   rewritten to a canonical token `$·<level>`. A read whose name is **not** in
   scope is a **free reference** (dependency / global / builtin) and keeps its name
   for step 3. Binder forms that MUST be handled:
   - definition parameters (including `:named` and `:rest`);
   - `[?let]`-family bindings;
   - lambda / `[?fn ($x …) body]` parameters;
   - for-comprehension binds (`:in $x`, `:let $x = …`);
   - pattern binds (pattern-position bindings including `$name::T` type-tests and
     `*$name` rest-captures).
   The definition **name** is never emitted into `N`.

3. **Resolve free references to dependency hashes (Merkle DAG).** A free call or
   reference naming a sibling/imported **definition** is replaced by that
   definition's **Tier-2 hash**, so identity is transitively complete and
   dependency-aware. Free names resolving to **builtins / directive heads** are part
   of the language and are kept verbatim (their identity is their name). Resolution
   scope is the program/module being hashed plus its import closure.

4. **Mutual recursion is one component.** Definitions in a dependency **cycle**
   (e.g. `even-p`/`odd-p`) cannot each embed the other's hash. Compute the
   strongly-connected component over the dependency graph and hash the **whole
   component as one unit**: render the member definitions in a canonical intra-cycle
   order (by their name-independent normalized bodies), with intra-cycle references
   rewritten to a positional `@scc<k>` token, and take one SHA-256 over the
   concatenation. Every member shares that one component hash as its dependency
   contribution; a member's own Tier-2 hash is `SHA-256(component-hash ‖ position)`.
   An acyclic definition is the degenerate component of size 1.

## 3 — Surface & storage

- Core: `cx_code_tier2_hash(def_source) !string` (one definition) and
  `cx_program_tier2_hashes(program_source) !map[string]string` (name→hash, the name
  being the *alias*, not part of identity).
- Storage: `put-doc` / `get-doc` already key on a 256-bit hash; Tier-2 storage is
  the same store keyed by the Tier-2 hash in the opt-in **code namespace**.
  Alpha-equivalent definitions dedup to one stored object, retrievable by Tier-2
  hash; the code namespace is non-conflated with Tier-1 data documents.

## 4 — Conformance

Tier-2's guarantees are **collision / non-collision** properties over PAIRS of
inputs (these two inputs hash the same / differently), which the single-input
conformance corpus cannot express. The properties are therefore asserted by
behavioral tests at the hash level:

- alpha-equivalence (parameter + nested `fn`/`let`), name-independence, comment +
  whitespace insensitivity, semantic / operator distinctness;
- dependency sensitivity (callee body change → caller change; callee rename →
  caller stable), builtin-is-not-a-dependency, mutual recursion hashed as one
  component (name-independent, behavior-sensitive, members distinct), self-recursion
  name-independent;
- content-addressed code storage: Tier-2-equivalent definitions dedup to one
  stored object, distinct computations stay separate, code namespace non-conflated
  with Tier-1.

## 5 — Scope

A searchable, function-level, dependency-aware **index** (find-by-hash across a
corpus, rename-refactor via the alias layer, incremental re-hash) is a later
extension and is not part of this identity definition.
