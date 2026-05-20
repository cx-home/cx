# Perceus as a formal foundation for production-ready autofree

*Goal of this post: request a technical dialogue with the V core team about whether the Perceus reference-counting discipline (Reinking et al., POPL 2021) could serve as a principled foundation for finishing autofree — the v1.0 milestone V has already committed to. **Not** a request to add a new memory model, new syntax, or a new opt-in flag.*

## TL;DR

V's roadmap commits to "autofree memory management option ready for production" as a v1.0 goal. Today, autofree handles ~90–100% of objects, with reference counting filling the residual. The challenge is closing that gap *soundly* — proving the compiler's inserted `free` calls are safe in every reachable program, not just most of them.

**Perceus is a published, peer-reviewed discipline for doing exactly this.** It is not a new memory model; it is the formal floor under what autofree is already trying to be. It has been implemented at production quality in [Koka](https://koka-lang.github.io/) and [Lean 4](https://leanprover.github.io/), where it competes with hand-written C on real workloads — Lean 4's entire theorem prover and elaborator run on it.

What I'm proposing for dialogue:

1. Adopt Perceus's **insertion algorithm** as the formal specification of autofree's frees (and the residual RC ops). Same observable behavior; rigorous soundness story.
2. Adopt Perceus's **reuse / in-place mutation optimization**, which makes uniquely-owned data mutate without copy — `arr << x` becomes O(1) on unique arrays, matching what Rust gets from `&mut` *without* lifetime annotations.
3. Keep everything else V already has: no new keywords, no `&mut`/`&` distinction, no lifetimes, no opt-in flag. The Boehm GC remains the default and the escape hatch.

The rest of this post explains the framing, the gain, the cost, and the explicit non-goals — and asks the core team what they think.

---

## 1. Why this isn't another ownership/borrowing proposal

[Discussion #20490](https://github.com/vlang/v/discussions/20490) proposed Mojo-style ownership and borrowing. The core team's response was reasonable: V should not become a Rust dialect, and stacking another opt-in memory mode on top of autofree + GC would bloat the language. I agree with both points.

This proposal is structurally different:

| Aspect | #20490 (Mojo-style) | This proposal (Perceus) |
|---|---|---|
| New syntax | `&T`, `&mut T`, move semantics | **None** |
| New compiler flag | yes (opt-in) | **None** — strengthens existing `-autofree` |
| Programmer annotations | required | **None** |
| Concept user must learn | borrow checker | **None** — code looks identical |
| Status relative to roadmap | new feature | finishes a v1.0 milestone |

Perceus does its work entirely inside the compiler. Source code stays exactly as it is today. The user-visible change is: autofree becomes sound and complete enough to be the default, the GC becomes the escape hatch rather than the workhorse, and uniquely-owned mutations get faster.

## 2. What Perceus actually is, in one paragraph

Given a function, the Perceus algorithm walks the IR and inserts the **minimum sufficient** set of `dup` (refcount increment) and `drop` (decrement, freeing at zero) operations to make every program path memory-safe. Unlike naive RC, it does not bump on every assignment — it tracks ownership flow through the function and only emits ops at the points where ownership genuinely transfers or ends. It then runs a **reuse analysis**: when a value is about to be dropped, and a new value of compatible shape is about to be allocated on the same path, the old allocation is reused in place. The net effect on unique data is zero allocation traffic and zero refcount traffic in the hot path. Cycles are the honest cost: programs that build cyclic graphs leak unless an opt-in cycle collector is enabled (Koka does this; Lean 4 forbids cycles structurally).

Original paper: [Perceus: Garbage Free Reference Counting with Reuse](https://xnning.github.io/papers/perceus.pdf) (Reinking, Xie, de Moura, Leijen — POPL 2021).

## 3. Why this fits V's stated direction

Three points of alignment:

**a. It matches V's design ethos.** V's pitch has always been "no GC pauses, no annotations, fast compile, readable code." Perceus is the only published memory discipline that delivers all four simultaneously. Borrow-checking sacrifices readability; tracing GC sacrifices pauses; manual sacrifices safety. Perceus is the corner of the design space V is already trying to occupy.

**b. It matches autofree's actual mechanics.** Autofree today already inserts frees at compile time and falls back to RC for the residual. That is the Perceus shape, minus the proof of completeness and the reuse optimization. Treating autofree as "Perceus, but informally specified" reframes the v1.0 milestone from a research problem ("can we make autofree handle every case?") into an engineering problem ("can we port a published algorithm into V's IR?").

**c. It matches V's performance posture without compromising it.** [Lorenzen et al.'s "Reference Counting with Frame Limited Reuse" (PLDI 2023)](https://www.microsoft.com/en-us/research/publication/reference-counting-with-frame-limited-reuse/) extends Perceus to functional-update patterns and reports performance within 5–15% of hand-written C across the benchmark suite. Lean 4's elaborator — one of the most performance-sensitive workloads in any compiled language — runs on this. The "RC is slow" intuition predates Perceus; it does not apply.

## 4. What changes inside the compiler

At a high level, three pieces of work:

1. **Replace autofree's free-insertion pass** with the Perceus algorithm operating on V's IR. The current autofree pass would become a special case (the cases it handles today are exactly the ones Perceus handles trivially, so behavior on existing autofree-clean code is preserved).

2. **Add the reuse analysis pass** downstream of free insertion. This is the optimization that turns `arr = arr.map(f)` into an in-place update on unique arrays. It is a local dataflow pass; complexity is modest.

3. **Define V's cycle policy.** Two viable options:
   - **Koka-style:** ship an opt-in cycle collector for the GC mode; pure Perceus mode leaks on cycles (programs that build them are rare and usually buggy anyway).
   - **Lean 4-style:** disallow cyclic constructors structurally; require users to break cycles with weak references or arena indices.

   Either is defensible. Both preserve the current GC mode as a safe fallback for programs that genuinely need cycles. If pressed, I'd lean toward the Koka-style opt-in collector: it's a smaller foot-gun for application-level code where cyclic data (DOM-like trees, doubly-linked lists, ASTs with parent pointers) appears occasionally and a structural prohibition would force users into arena-index workarounds. But this is exactly the kind of call the core team is better positioned to make, since it depends on the V user-base's actual code shape.

What does *not* change: the V grammar, the standard library's public API, the `-gc` flag, the existing autofree user experience (it just stops having sharp edges), or the build pipeline.

## 5. Quantifying the gain (intuitive frame)

Comparing four configurations on the dimensions that matter:

| Property | V today (default GC) | V today (`-autofree`, experimental) | V + Perceus | Rust |
|---|---|---|---|---|
| Memory safety | runtime (via GC) | unsound on ~0–10% of programs | **sound, compile-time, proven** | sound, compile-time |
| Deterministic destruction | no (GC pauses) | mostly | **yes** | yes |
| Predictable performance | no | yes | **yes** | yes |
| Performance vs C | ~1.3–1.5× | ~1.0–1.2× when sound | **~1.0–1.2×** | ~1.0–1.05× |
| Annotation burden | none | none | **none** | substantial |
| Data-race freedom | no | no | no | yes |

On workloads V actually targets — application code, parsers, CLIs, data tooling — Perceus reaches roughly **90% of Rust's effective value** at roughly **0% of Rust's annotation cost**. The residual is data-race freedom, which Perceus does not address. That's a separate conversation (Pony-style reference capabilities are the natural follow-up, and V's existing channel-based concurrency model already covers the common case), and it is explicitly out of scope here.

## 6. Honest costs and tradeoffs

I want to be straightforward about what this isn't free:

**a. Implementation cost is real.** Perceus is a published algorithm with reference implementations, but porting it to V's IR is meaningful compiler work — probably on the order of months, not weeks, even with the papers in hand. The reuse analysis is the hardest part. I'm not pretending this is a weekend patch.

**b. Cycle handling requires a choice.** See §4. Both options have downsides; the V team is best positioned to choose which downside is more palatable for V's user base.

**c. RC traffic is not literally zero.** On code paths where uniqueness cannot be statically proven (reference shared across closures, threads, or long-lived data structures), `dup`/`drop` ops remain. Empirically they are a small constant fraction of runtime — but they are not free, and benchmarks should be honest about this.

**d. The threading story interacts with the GC threading work.** V already has some thread-registration C ABI (`cx_init`-style patterns in downstream projects suggest this is a known surface). Perceus's RC ops must be either atomic or thread-local; Koka uses thread-local with explicit handoff, Lean 4 uses atomic. Either works; the choice has perf implications worth a separate discussion.

**e. No silver bullet for data races.** As above. Perceus is a memory-safety discipline, not a concurrency-safety discipline. Anyone hoping this would close the Rust gap for lock-free data structures will be disappointed.

## 7. Explicit non-goals

To preempt the natural concerns from #20490 and elsewhere:

- **Not adding new syntax.** No `&`, no `&mut`, no `move`, no lifetimes, no `'a`.
- **Not adding a new memory mode.** GC stays the default until the team decides otherwise. Manual mode stays. `-autofree` stays — it just becomes sound.
- **Not removing the GC.** The GC remains the fallback for programs that need cycles, the escape hatch for unusual patterns, and the default for users who don't want to think about it.
- **Not asking V to become Rust.** Perceus is specifically the path that *avoids* Rust-ness.
- **Not requiring user opt-in to benefit.** Existing autofree users get a sound compiler; existing GC users are unaffected.

## 8. What I'm asking for

A technical dialogue. Specifically:

1. **Does the core team see autofree's v1.0 milestone as fundamentally a soundness/completeness problem, or as something else?** If something else, I'd genuinely like to understand the framing — it would change this proposal substantially.

2. **Is there appetite for adopting a published, peer-reviewed discipline as the formal spec for autofree?** Or is the team's preference to evolve autofree's heuristics organically?

3. **If yes, which cycle policy fits V better — opt-in collector or structural disallowance?** This is the highest-impact design call.

4. **Are there V-specific constraints (e.g., C interop patterns, compile-time complexity budget, specific language features that resist RC-style analysis) that would make Perceus a poor fit?** I've studied V from the outside; the core team knows things I can't.

5. **Would a small proof-of-concept on a subset of V's IR be useful as an artifact for further discussion?** Or is the conceptual question more important to resolve first?

## 9. Prior art and references

**Core algorithm:**
- Reinking, Xie, de Moura, Leijen. *Perceus: Garbage Free Reference Counting with Reuse.* PLDI 2021. [PDF](https://xnning.github.io/papers/perceus.pdf)
- Lorenzen, Leijen, Swierstra. *Reference Counting with Frame Limited Reuse.* OOPSLA 2023.

**Production implementations:**
- [Koka](https://github.com/koka-lang/koka) — research language, primary Perceus implementation.
- [Lean 4](https://github.com/leanprover/lean4) — theorem prover. The entire elaborator and tactic framework run on Perceus.

**Related V discussions (acknowledged, not duplicated):**
- [#20490 — Ownership+borrowing without lifetime labeling](https://github.com/vlang/v/discussions/20490) — different proposal; this one is complementary, not competing.
- [#16553 — When will autofree be production-ready?](https://github.com/vlang/v/discussions/16553) — the milestone this proposal is in service of.
- [#13588 — How close is autofree to completeness?](https://github.com/vlang/v/discussions/13588) — the completeness question Perceus addresses formally.
- [#11649 — V concurrency considerations](https://github.com/vlang/v/discussions/11649) — relevant to threading interaction.

**Adjacent surveys / good background reading:**
- Verdagon, [Borrow checking, RC, GC, and the Eleven (!) Other Memory Safety Approaches](https://verdagon.dev/grimoire/grimoire) — places Perceus in context.

---

Thanks for reading. I'm posting this in Discussions rather than as an Issue because the right next step is conversation, not a PR. I'm happy to be told this is the wrong frame; if it is, what I'm really asking is *what's the right frame for finishing autofree?*

— Erik (@eptx)
