# `cx-stdlib/bus` — in-process pub/sub with synchronous ordered dispatch

```cx
[module-meta name=bus tier=D status=current]
```

**Status:** Current

Normative reference (on graduation) for the `cx-stdlib/bus` sub-package: a single
in-process message bus that delivers each published message to its matching
subscribers **synchronously, in a defined order**, with a **re-entrant emission
queue** so a message a handler publishes during dispatch is processed *before the
next externally-published message*. It has **no socket, no thread, and no timer**
of its own — effects occur only inside the handlers it invokes (§2.3, §5).

## §0. Consistency with the in-review amendments (normative dependency)

Authored to be consistent with the same SAP amendments the sibling web-stack
drafts align to ([`http.md`](http.md) §0,
[`net.md`](net.md) §0); on their approval the cited semantics are
load-bearing here. If any is rejected or changed at G3, the marked clauses are
revisited.

| Amendment | What bus relies on |
|---|---|
| `code.md` §9.1.2 — **four-channel model** | a successful publish that matched **zero** subscribers is a **present value** (a `[dispatch]` summary, §2.4), **not** a fault and **not** absence — "no subscriber" is a normal outcome of pub/sub. **No subscriber for a topic → the absence channel never fires**; subscription lookup that finds nothing yields an **empty node-set** (§3.4), not `null` (no-conflation guard). A handler that raises rides the **failure channel** (`[err]`), surfaced per the §4.3 isolation policy. |
| SAP §1 — **a non-fault result is a VALUE** | `emit` returns a `[dispatch delivered=N …]` **value** describing what happened (subscribers fired, in order); it is inspected, not caught. Faults are reserved for genuine misuse (§8). |
| SAP §2 — **`[?try]`/`[catch]`/`[on-error]` retirement** | handler faults are handled with `[?match]` / `[?else]` / `[?fallback]` only; this spec never uses `[?try]`. Canonical call form is `[$bus:on …]` (`[head …]`), never an infix form. |
| SAP §5.1 — **`[?with-open]` closeable contract** | a `[bus]` handle and a `[subscription]` handle satisfy the closeable contract (`on-close="bus/close"` / `"bus/off"`); closing a bus drops all subscriptions, closing a subscription unsubscribes it. Both are idempotent and never raise `CXER0108`. |
| `spec-authoring-guide.md` §3 / SAP §0.2 — **orthogonality guard** | the §7 Applicability Matrix + `UNIFORM` gate are mandatory. |

bus does **not** provide the **log**, the **hash chain**, **replay/fold**, or the
**commit-order coupling** — those are [`journal.md`](journal.md), and
the *cascade composition* that wires emit ⇒ append ⇒ dispatch is
[`xap.md`](xap.md) (§2.4, §6). bus is the ordered-dispatch primitive
only.

---

## §1. Scope

`cx-stdlib/bus` provides **in-process publish/subscribe**: a `[bus]` handle to
which subscribers attach `(pattern, handler)` registrations, against which
messages are published, and from which each published message is delivered to all
matching subscribers **synchronously and in a defined order**. It provides
**subscribe** (`on`), **publish** (`emit`), **unsubscribe** (`off`), and
**introspection** (`subscribers`, `topics`, `match`). Pattern matching is over a
message's **head/topic and shape**, using a **CXPath-ish** form (§2.2).

**The one guarantee** (§4): dispatch is **synchronous, deterministic, and
ordered**, with a **re-entrant emission queue** so a handler's own `emit` during
dispatch is processed before the next externally-published message. **Fire-and-forget
asynchronous delivery and nondeterministic ordering are NOT offered** — they would
break the replay/determinism XAP depends on (§2.4, [`xap.md`](xap.md) N-CORE-1).

Out of scope (and where it lives instead):

| Concern | Owner |
|---|---|
| Append-only **log**, **hash chain**, **fold → state**, **replay / dry-run** | [`journal.md`](journal.md) |
| The **synchronous serialized cascade** (emit ⇒ journal append ⇒ dispatch in commit order ⇒ sub-emissions before the next external message) | [`xap.md`](xap.md) §2 (a *composition rule* over `bus` + `journal`, not a bus primitive) |
| **Authority / capability check before commit** (the PEP) | [`authz.md`](authz.md) (the bus is not the PEP here; in XAP the *cascade* runs the check, [`xap.md`](xap.md) §22.3) |
| Cross-process / network message transport | not a bus concern — bus is **in-process only**; cross-process fan-out is a `net`/`http` (SSE) transport above it ([`xap.md`](xap.md) §16) |
| Threads, fibers, timers, scheduled events | the host event loop / `[?worker]` / the http timer enhancement ([`xap.md`](xap.md) §25.1); bus spawns **none** |
| Backpressure / bounded mailboxes / drop policies | n/a — there is no async mailbox to bound (delivery is synchronous, §4.1) |

`cx-stdlib/bus` is **Tier-B runtime**. Bus *construction* and *introspection* are
**pure** and capability-free; **publishing is conditionally effectful** — `emit`
itself performs no syscall, but it **invokes subscriber handlers**, whose effects
are the handlers' own (§2.3, §5). The bus **introduces no new capability**.

## §2. Conceptual model

### §2.1. The `[bus]` handle, subscriptions, and concurrency

```cx
[bus state="open" dispatching=false on-close="bus/close"]   # an in-process bus instance

[subscription id="s-7" topic=":order.placed"               # one (pattern, handler) registration
  state="active" on-close="bus/off"]
```

A **bus** owns an **ordered list of active subscriptions**. A **subscription** is
a `(pattern, handler, priority, id)` registration produced by `on` (§3.2) and
identified by a stable `id` for `off` (§3.3). Ownership / concurrency contract:

- A `[bus]` is **single-threaded by contract.** All of `on` / `emit` / `off` /
  introspection on one bus MUST run on **one owner** (fiber/thread). Bus delivery
  is synchronous (§4.1), so there is no internal lock and no concurrency-safety
  claim. Concurrent or non-owner use of a `[bus]` →
  `cx-err:CXER4661 E_BUS_HANDLE_RACE`. *(Contrast `http`'s pooled, concurrency-safe
  client — bus is the opposite: deliberately serial.)* Fan-out across workers is
  done **above** the bus (each worker owns its own bus; cross-worker delivery is a
  transport, §1), never by sharing one `[bus]`.
- `state`: bus ∈ `"open" | "closed"`; subscription ∈ `"active" | "cancelled"`.
- `dispatching` is `true` only **while** an `emit` cascade is draining (§4.2); it
  is observable so re-entrancy is well-defined.
- Both handles carry the **closeable contract** (SAP §5.1,
  [`code.md`](../core/code.md) §8.10.7): `[?with-open]`-able, never raise
  `CXER0108`. Closing a `[bus]` cancels every subscription and marks it `"closed"`;
  closing a `[subscription]` is exactly `off` (§3.3). Both are **idempotent**.
- **Mutation during dispatch (pinned).** `on` / `off` MAY be called from inside a
  handler. Changes take effect for the **next** message, **never** mid-cascade: the
  subscriber set for an in-flight message is **snapshotted** when delivery of that
  message begins (§4.2). This keeps dispatch deterministic and avoids
  iterator-invalidation.

### §2.2. Messages and patterns — `[do …]`-shaped, CXPath-matched

A **message** is any CX element value. XAP's canonical message is an intent —
`[do :open $order]` ([`xap.md`](xap.md) §13.1) — but bus is **general**: any
`[head …]` element publishes. A message's **topic** is, by default, the
composition of its **head** and its leading **atom** argument (the `[do …]` verb):

```cx
[do :order.placed [order id="42"]]      # head = do,   topic = :order.placed
[metric :cpu val=0.91]                   # head = metric, topic = :cpu
[order-card-rerender id="42"]            # head = order-card-rerender (no atom) → topic = the head name
```

A **pattern** selects messages by topic and/or shape. Three pattern forms, in
ascending power, all **pure** to evaluate:

| Pattern form | Example | Matches |
|---|---|---|
| **topic atom** | `:order.placed` | messages whose topic equals the atom; a trailing `-` is a **prefix-glob** (`:order-` matches `:order.placed`, `:order-cancelled`) |
| **head name** | `'metric'` (string) | messages whose **head** equals the name, any arguments |
| **predicate fn** | `[?fn ($m) [= $m/do :refund]]` | an **arity-1 boolean callable** over the message value (returns true to match); full structural power via CXPath inside the function body |

> **Grammar adaptation (impl-reconciled).** Two earlier-draft forms in this
> section did not parse and are corrected here to the realized surface (same
> precedent as `net` `addr->string` → `addr-to-string`): (1) the prefix-glob is
> a **trailing `-`** (`:order-`), not `:order.*` — `*` is not an atom `NameChar`
> ([`grammar.ebnf`](../formal/grammar.ebnf) [6a]), so a
> dotted-star glob is unlexable; (2) the structural pattern is an **arity-1
> boolean `[?fn …]`**, not a bare `[?[= …] …]` predicate literal (which is not a
> grammar production). Topics are dash-separated atoms (`:order.placed`); a `.`
> is a legal `NameChar` but the module's convention is `-`.

Glob and the predicate fn are the **only** wildcard/structural mechanisms; there
is no regex. The matcher is a **pure** function (`match`, §3.4) — given a message
and a pattern it is referentially transparent, so "which subscribers would
fire?" is answerable without side effects (the dry-run hook XAP's resolver
reuses, [`xap.md`](xap.md) §19).

> **Topic derivation is pinned, not magic.** The head+leading-atom rule above is
> the single, total topic function. A message with no leading atom has its **head
> name** as topic. `topic` (§3.4) computes it; callers never guess.

### §2.3. The bus invokes handlers; it performs no effect of its own

`emit` itself reaches **no** OS resource — it appends to an internal queue and
synchronously calls matching handlers in order (§4). Any effect (I/O, a journal
append, a state write) is performed **by a handler**, under that handler's own
capabilities (§5). The bus is therefore **"pure-ish": its only externally-visible
behavior is the handlers it calls, in the order it calls them.** This is why bus
adds **no new capability** and why an `emit` with zero matching subscribers is a
**pure no-op returning a `[dispatch delivered=0]` value** (§2.4).

### §2.4. What bus does NOT do — the cascade lives in `xap`/`journal` (the boundary)

bus provides **ordered dispatch**. It does **not**:

- append the message to a log (no `journal` coupling — [`journal.md`](journal.md));
- enforce the **commit rule** ("a message commits only after its sub-emissions
  drain, before the next external message") *as a logged transaction* — bus offers
  the **ordered drain** (§4.2) the rule is built on, but the *commit* (append +
  hash-chain + authority check) is the cascade composition in
  [`xap.md`](xap.md) §2 / §14;
- check authority (the PEP is [`authz.md`](authz.md), driven by the
  *cascade*, not the bare bus, [`xap.md`](xap.md) §22.3).

> **N-BUS-1 (synchronous ordered dispatch is the whole contract).** A `[bus]`
> delivers each published message to its matching subscribers **synchronously, in
> a defined order**, and fully drains a message's re-entrant emissions **before**
> the next externally-published message is delivered (§4.2). **Asynchronous,
> fire-and-forget, or nondeterministically-ordered delivery is not part of this
> module and MUST NOT be added** — it would break the replay/determinism XAP's log
> requires ([`xap.md`](xap.md) N-CORE-1). XAP layers commit-order *authority* on
> top of this primitive; bus supplies the *ordering*, not the *authority*.

This split is the same discipline as `http` ↔ `[?http-service]`: bus is the thin
reusable engine; the XAP cascade is the composition above it.

## §3. Public function surface

Signature notation matches [`cx-stdlib/io`](../std-lib/io.md) and
[`http.md`](http.md). `::element` is a `[bus]` /
`[subscription]` handle or a message element; `::pattern` is one of the three §2.2
pattern forms (an atom, a string head-name, or a `[?…]` CXPath predicate
element); `$handler` is a callable (a `[?def]`, a closure, or a `[?fn]`) of arity
1 — it receives the message element. A read that may be absent is typed
`[returns element]` / `[returns [sequence element]]` and yields the **absence
channel** (empty node-set) when nothing matches (§2.5 of the four-channel model).

### §3.1. Bus construction (pure)

```
[?def bus   scope=public pure   [returns element] ($opts::map {}) ...]
[?def close scope=public impure [returns null]    ($bus::element) ...]
```

`bus` constructs a fresh `[bus]` with **no subscriptions**; it touches no OS
resource, so it is **pure** (referentially transparent — two `[$bus:bus]` calls
yield two independent, equal-shaped empty buses). The trailing `$opts::map {}` is a
**defaulted positional parameter** (`grammar.ebnf [153b]` — a bare space-separated
VALUE after the type, per [`http.md`](http.md) §3.1), so
`[$bus:bus]` ≡ `[$bus:bus {}]`. `close` is **idempotent**, marks the bus
`"closed"`, and cancels every active subscription (impure only because it mutates
handle state and finalizes subscriptions; it performs no I/O). `opts`:

| Key | Default | Meaning |
|---|---|---|
| `on-fault` | `:isolate` | handler-fault policy (§4.3): `:isolate` (record, continue), `:halt` (stop the cascade, surface the fault), `:collect` (continue, aggregate into the `[dispatch]`) |
| `max-cascade-depth` | `1000` | re-entrant emission depth cap (§4.4); exceeding → `CXER4663` — **never unbounded** |
| `max-cascade-events` | `100000` | total messages drained in one external `emit` cascade (§4.4); exceeding → `CXER4663` |
| `topic-of` | builtin (§2.2) | optional override of the topic-derivation function (an arity-1 pure callable message→atom); MUST be pure |

### §3.2. Subscribe — `on`

```
[?def on scope=public impure [returns element] ($bus::element $pattern::pattern $handler $opts::map {}) ...]
```

`on` registers `$handler` to fire on every future message matching `$pattern`
(§2.2) and returns a `[subscription id=… …]` handle (impure: it mutates the bus's
subscription list). The subscription is **appended** to the ordered list, so by
default subscribers fire in **registration order** (§4.1); `opts.priority` (an
`int`, higher fires first; ties broken by registration order) overrides. `opts`:

| Key | Default | Meaning |
|---|---|---|
| `priority` | `0` | dispatch-order key; higher fires first, ties → registration order (§4.1) |
| `once` | `false` | when `true`, the subscription auto-cancels after its **first** matching delivery (a one-shot) |
| `id` | impl-generated | a caller-chosen stable id (must be unique on the bus, else `CXER4662`); else the bus assigns one |

A `[subscription]` satisfies the closeable contract (`on-close="bus/off"`,
§2.1) — `[?with-open [$bus:on $b :tick $h] $s …]` auto-unsubscribes on scope exit.
Registering during a dispatch is allowed and takes effect for the **next** message
(§2.1, §4.2). A non-callable `$handler` or a malformed `$pattern` →
`cx-err:CXER4660 E_BUS_ARG_INVALID` at registration (fail fast).

### §3.3. Unsubscribe — `off`

```
[?def off scope=public impure [returns bool] ($bus::element $sub::element) ...]
```

`off` cancels a subscription — accepting either the `[subscription]` handle or its
`id` string — and returns `true` iff a matching **active** subscription was found
and cancelled, `false` if it was already cancelled / unknown (a value, not a
fault — idempotent unsubscribe is normal, SAP §1). Cancelling **during** a
dispatch takes effect for the **next** message; if the cancelled subscription has
not yet fired for the **in-flight** message, it is **removed from the current
snapshot too** (a handler may cancel a not-yet-fired peer) — the one mid-cascade
mutation that is honored, because it can only *shrink* the remaining set (never
re-order or grow it), preserving determinism (§4.2). `off` on a closed bus →
`cx-err:CXER4664 E_BUS_HANDLE_CLOSED`.

### §3.4. Publish — `emit`

```
[?def emit scope=public impure [returns element] ($bus::element $msg::element $opts::map {}) ...]
```

`emit` publishes `$msg` to the bus and **synchronously drives the full ordered
dispatch** (§4), returning a `[dispatch …]` **value** (SAP §1) summarizing the
cascade — it is **inspected**, not caught:

```cx
[dispatch delivered=3 topic=:order.placed depth=2 events=4
  [fired [subscription id="s-1"] [subscription id="s-4"] [subscription id="s-9"]]   # in fire order
  [faults]]                                                                          # empty unless on-fault=:collect
```

- `delivered` — count of handlers that fired for `$msg` itself (its snapshot).
- `events` — total messages drained in the cascade (`$msg` + all re-entrant
  emissions, §4.2); `depth` — max re-entrancy depth reached.
- `fired` — the subscriptions that fired **for `$msg`**, in fire order
  (observability for dry-run / audit).
- `faults` — present-empty by default; under `on-fault=:collect` it carries each
  handler's `[err]` (§4.3).

`emit` is classified **impure** because it *may* invoke effectful handlers; with
**zero matching subscribers** it is a **pure no-op** returning
`[dispatch delivered=0 …]` (§2.3 — "no subscriber" is a normal value, not absence,
not a fault). `opts`:

| Key | Default | Meaning |
|---|---|---|
| `on-fault` | bus default (§3.1) | per-`emit` override of the fault policy (§4.3) |
| `sync` | n/a | **reserved & rejected** — there is no async mode; passing `sync=false` → `cx-err:CXER4665 E_BUS_ASYNC_UNSUPPORTED` (the explicit "no fire-and-forget" guard, §4.1, pinned by a negative fixture) |

### §3.5. Introspection (pure)

```
[?def subscribers scope=public pure [returns [sequence element]] ($bus::element $pattern::pattern {}) ...]
[?def topics      scope=public pure [returns [sequence element]] ($bus::element) ...]
[?def match       scope=public pure [returns [sequence element]] ($bus::element $msg::element) ...]
[?def topic       scope=public pure [returns element]            ($msg::element) ...]
[?def matches     scope=public pure [returns bool]               ($msg::element $pattern::pattern) ...]
```

All **pure** — they read the bus's subscription list / compute over a message
value, never fire a handler, never mutate (referentially transparent):

- `subscribers` — active `[subscription]`s, in **dispatch order** (§4.1); with a
  `$pattern` argument (optional, §2.2), only those whose **registered pattern is at
  least as specific as** `$pattern` (a registry query) — or the **empty node-set**
  if none (absence channel, never `null`).
- `topics` — the distinct topic atoms currently subscribed (the registry's topic
  set), in registration order of first appearance.
- `match` — the subscriptions that **would fire** for `$msg`, in fire order,
  **without firing them** (the dry-run primitive). Empty node-set when none.
- `topic` — the topic atom of `$msg` per the §2.2 derivation (total).
- `matches` — `true` iff `$msg` matches `$pattern` (the bare matcher, §2.2).

## §4. Semantics & guarantees (soundness)

### §4.1. Synchronous, deterministic, ordered delivery
`emit` does not return until **every** handler the cascade triggers has run to
completion (§4.2). For a single message, matching subscribers fire in a **total
order**: descending `priority`, ties broken by **ascending registration order**
(insertion order on the bus). The order is a **pure function of the bus's
subscription list and the message** — re-running `emit` on an equal bus + equal
message fires the same subscriptions in the same order (the determinism XAP's
replay requires, [`xap.md`](xap.md) N-CORE-1). **There is no asynchronous mode**:
delivery is always on the calling fiber, in-line (`emit sync=false` →
`CXER4665`, §3.4).

### §4.2. Re-entrant emission queue — drain before the next external message
A handler MAY call `emit` on the same bus during its own dispatch. Such a
**re-entrant emission is enqueued, not dispatched immediately**, and the queue is
drained **breadth-first in enqueue order** (FIFO) **before the outer `emit`
returns** — so all messages a cascade produces are processed **before the next
externally-published message** is delivered. Mechanically, for an external `emit M`:

1. snapshot M's matching subscribers (§2.1) and append M to the cascade queue;
2. dequeue the head message; fire its snapshotted subscribers in §4.1 order;
3. any `emit` a handler makes **appends** to the cascade queue (it does **not**
   recurse the V/host stack — re-entrancy is queued, bounding stack growth);
4. repeat 2–3 until the queue is empty; **then** the external `emit` returns its
   `[dispatch]`.

This **ordered drain is the primitive** the XAP serialized cascade composes with a
journal append + authority check ([`xap.md`](xap.md) §14, §2.4 above). bus
guarantees the **ordering**; the *commit transaction* is XAP's. FIFO (not LIFO) is
chosen so causally-earlier sub-emissions are processed before later ones —
matching a log's append order.

### §4.3. Handler-fault isolation (the `on-fault` policy)
A handler that raises an `[err]` (or panics with `!`) does **not** corrupt the
bus. The configured policy (§3.1/§3.4) governs the cascade:

| Policy | Effect of a handler fault |
|---|---|
| `:isolate` *(default)* | the fault is **recorded** against that subscription, the cascade **continues** with the remaining subscribers/queue; the offending handler's own emissions (if any, before it raised) stand. The `[dispatch]` carries `faulted=true` but `faults` stays empty (use `:collect` to capture). |
| `:collect` | as `:isolate`, but each fault `[err]` is **aggregated into `[dispatch]/faults`** for the caller to inspect — non-failing delivery with full diagnostics. |
| `:halt` | the cascade **stops at the faulting handler**; subscribers not yet fired do not fire; the queue is discarded; `emit` surfaces the handler's `[err]` on the **failure channel** (it propagates per `code.md` §9.2). The strict mode for transactional callers (XAP's cascade selects this so a failed intent aborts cleanly). |

A fault is **always** a handler's own `[err]`; the bus never converts a non-2xx-style
**value** outcome into a fault (there is no such notion — a handler returning any
value is success; its return is ignored, §4.5).

### §4.4. Bounded cascades — no runaway re-entrancy
The re-entrant queue (§4.2) makes cycles possible (handler A emits X, handler for X
emits Y that A matches…). Two caps make every cascade terminate:
`max-cascade-depth` (§3.1) bounds re-entrancy **depth**; `max-cascade-events`
bounds **total messages** drained in one external `emit`. Exceeding either →
`cx-err:CXER4663 E_BUS_CASCADE_LIMIT` (the cascade aborts, the partial `[dispatch]`
is attached to the `[err]` for diagnosis). **Neither cap is ever unbounded** — a
buggy cyclic handler graph fails loudly, never hangs.

### §4.5. Handler return values are ignored; emissions are the channel
A handler influences the world **only** by its side effects and by `emit`-ing
further messages — its **return value is discarded** (bus is a dispatcher, not a
fold; aggregation/state is `journal`'s job, [`journal.md`](journal.md)).
This keeps the bus contract minimal and the handler signature uniform (message →
unit).

### §4.6. Handle lifecycle
An op on a `"closed"` bus → `cx-err:CXER4664 E_BUS_HANDLE_CLOSED`; `on`/`emit`/
`off`/introspection all check first. `close` is idempotent and cancels all
subscriptions (§3.1). A `[subscription]`'s `off` is idempotent (§3.3). Handles are
**not** quota-counted against net's open-handle pool (no OS resource backs them).

## §5. Capability integration

The bus **introduces no new capability** and **gates nothing of its own** — it
opens no socket, file, or process. `bus` / `close` / `on` / `off` and all
introspection are **capability-free**.

| Operation | Capability | Resource matched |
|---|---|---|
| `bus` / `close` / `on` / `off` | — | in-process handle mutation only (no effect) |
| `subscribers` / `topics` / `match` / `topic` / `matches` | — | **pure** (§3.5) |
| `emit` | **none of its own** | inherits **whatever capabilities its handlers require** — each effect a handler performs is gated at *that handler's* effect point (`net`, `store`, …), reported by *that* primitive |

So a denial during dispatch surfaces as the **handler's** capability fault
(`cx-err:CXER0271 E_CAP_DENIED` at the handler's effect point,
[`security.md`](../core/security.md) §2–§4), not a bus code — bus is transparent to
the capability model. **Cancellation** (`[?timeout]`/`[?cancel]` wrapping an
`emit`) follows SAP §5.2: a cancelled handler at a cancellation point reports the
core `CXER0260`; the cascade then **halts** (treated as `:halt`, the in-flight
drain stops) and `emit` propagates `CXER0260`. `[?with-open]` close runs under
restored caps.

## §6. Composition with the integration layer

Canonical call form is `[$bus:VERB …]` (`[head …]`); this module uses **no infix**
(SAP §2.1). Inspect an `emit` outcome by **shape**, not `[?try]` — a `[dispatch]`
is a value, a handler fault under `:halt` is `[err]`:

```cx
[?with-open [$bus:bus] $b
  [?with-open [$bus:on $b :order.placed [?fn ($m) [$store:put 'orders' $m]]] $s1
    [?with-open [$bus:on $b [?fn ($m) [= $m/do :order.placed]] [?fn ($m) [$bus:emit $b [do :notify $m]]]] $s2
      [?match [$bus:emit $b [do :order.placed [order id="42"]]]
        [case [err @code='cx-err:CXER4663'] [$log:warn 'cascade limit']]   # fault
        [case [dispatch @delivered=0] [$log:info 'no subscribers']]        # a VALUE (0 fired)
        [case $d $d]]]]]                                                   # normal dispatch value
```

- **The XAP serialized cascade ([`xap.md`](xap.md) §14)** is built **on top of**
  bus: `[$xap:…]` wires *emit ⇒ `[$journal:append]` ⇒ `[$authz:check]` (PEP) ⇒
  `[$bus:emit]` in commit order*, selecting `on-fault=:halt` so a failed intent
  aborts the transaction. bus supplies the **ordered drain** (§4.2); the **commit /
  hash-chain / authority** are [`journal.md`](journal.md) /
  [`authz.md`](authz.md), composed by [`xap.md`](xap.md).
- **Panel re-render fan-out ([`xap.md`](xap.md) §17/§18):** one committed intent
  `emit`s a slice-change message; subscribed panels (`on` their CXPath slice) fire
  in order — an out-of-band fragment swap for thin panels, a slice-event for
  working panels — **the seam dissolved by the bus** ([`xap.md`](xap.md) §18).
- **Resilience (`code.md` §10.2)** wraps `emit`: `[?timeout]` → `CXER0260`;
  `[?retry]` re-emits. **Recovery is `[?else]` / `[?match]`** (SAP §2), never
  `[?try]`.
- **Dry-run** ([`xap.md`](xap.md) §19/§22.10): `[$bus:match $b $msg]` answers "who
  would fire?" **without** firing — the pure primitive the resolver/audit reuse.
- **`[?with-open]` ([`code.md`](../core/code.md) §8.10.7):** auto-closes the bus
  (`on-close="bus/close"`) and subscriptions (`on-close="bus/off"`), idempotent with
  explicit `close`/`off`.

## §7. Applicability matrix (UNIFORM gate — authoring-guide §3 / SAP §0.2)

✅ supported; ❌ deliberately unsupported (rationale); — not applicable.

| Operation | atom topic pattern | head-name pattern | CXPath predicate pattern |
|---|:--:|:--:|:--:|
| `on` (subscribe) | ✅ | ✅ | ✅ |
| `off` (by handle / by id) | ✅ ¹ | ✅ ¹ | ✅ ¹ |
| `emit` (publish) | ✅ | ✅ | ✅ |
| `subscribers` (filtered) | ✅ | ✅ | ✅ |
| `match` / `matches` (dry-run) | ✅ | ✅ | ✅ |
| `topic` / `topics` | ✅ | ✅ ² | ✅ ² |

| Dispatch property | synchronous ordered | asynchronous / fire-and-forget |
|---|:--:|:--:|
| `emit` delivery | ✅ | ❌ ³ |
| re-entrant emission (handler `emit`s) | ✅ ⁴ | — ³ |
| nondeterministic / unordered delivery | — | ❌ ³ |
| bounded cascade (depth + event caps) | ✅ ⁵ | — |

| Concurrency property | one owner (serial) | shared `[bus]` across workers |
|---|:--:|:--:|
| `on` / `emit` / `off` | ✅ | ❌ ⁶ |

Footnotes: **1** `off` is pattern-independent — it cancels by subscription
identity, not by pattern; it is total and idempotent (§3.3). **2** `topic`/`topics`
operate on the message/registry regardless of how a subscriber's pattern was
expressed — the topic function is pattern-independent (§2.2). **3** asynchronous,
fire-and-forget, and nondeterministically-ordered delivery are **deliberately
unsupported** (N-BUS-1) — they break replay/determinism ([`xap.md`](xap.md)
N-CORE-1); `emit sync=false` → `CXER4665`, pinned by a negative fixture. **4**
re-entrant emissions are **queued and drained in order before the next external
message** (§4.2) — the ordered primitive, not async. **5** every cascade is bounded
(`max-cascade-depth` / `max-cascade-events`, §4.4) → `CXER4663`; **never unbounded**
(no hang on a cyclic handler graph). **6** a `[bus]` is single-owner by contract
(§2.1) — concurrent/non-owner use → `CXER4661`; cross-worker fan-out is a transport
above the bus (§1), not a shared handle.

Cognate-coverage: every pattern form works on `on`, `emit`, `subscribers`,
`match`, `matches`; every introspection accessor is pure and pattern-independent
where applicable. The intentional asymmetries (no async, single-owner) are
justified above and pinned by negative fixtures; each is a **deliberate design
invariant** (N-BUS-1, §2.1), not an open cell.

## §8. Error codes — `CXER4650–CXER4699` band (proposed allocation)

`CXER4650–CXER4699` is the **proposed allocation** for `cx-stdlib/bus` in the
governance registry ([`governance.md`](../process/governance.md) §9.6), the next
free block above `cx-stdlib/http`'s `CXER4525–4543`. This revision uses
`CXER4660–4665`; the remainder of the band is reserved for the module (and a
sibling XAP module MAY take an adjacent block — `journal`/`authz`/`session`/`xap`
allocations are proposed alongside their own drafts). All values use `cx-err:`
notation; symbolic↔wire is 1:1 (governance invariant). **Cancellation is the core
`CXER0260`, not a bus code** (§5); **capability denial during dispatch is the
handler's `CXER0271`, not a bus code** (§5).

| Code | Symbol | Raised when |
|---|---|---|
| `cx-err:CXER4660` | `E_BUS_ARG_INVALID` | non-callable `$handler`, malformed `$pattern` (not an atom / string head-name / `[?…]` CXPath predicate), or a non-element `$msg` (§3.2/§3.4) |
| `cx-err:CXER4661` | `E_BUS_HANDLE_RACE` | concurrent or non-owner use of a single-owner `[bus]` (§2.1) |
| `cx-err:CXER4662` | `E_BUS_DUPLICATE_ID` | `on` with a caller-chosen `opts.id` already active on the bus (§3.2) |
| `cx-err:CXER4663` | `E_BUS_CASCADE_LIMIT` | `max-cascade-depth` or `max-cascade-events` exceeded; carries the partial `[dispatch]` (§4.4) |
| `cx-err:CXER4664` | `E_BUS_HANDLE_CLOSED` | `on`/`emit`/`off`/introspection on a `"closed"` bus (§4.6) |
| `cx-err:CXER4665` | `E_BUS_ASYNC_UNSUPPORTED` | `emit` with `sync=false` (or any async-mode opt) — the explicit no-fire-and-forget guard (§3.4/§4.1, N-BUS-1) |

**Shared/core codes bus surfaces (not in its band):** `cx-err:CXER0260`
(cancellation of an `emit`, §5); `cx-err:CXER0271` (a **handler's** capability
denial, §5 — bus is transparent to it); `cx-err:CXER0108` never raised (handles are
closeable, §2.1). A **handler's** own `[err]` (any code) is surfaced or isolated per
the §4.3 `on-fault` policy — it is not re-coded by the bus.

## §9. Implementation notes (non-normative) — a list + a queue, no runtime

| bus surface | Building block | Note |
|---|---|---|
| `[bus]` handle | an ordered vector of `[subscription]` records + a single FIFO cascade queue | no lock (single-owner, §2.1); no thread; no fd |
| `on` / `off` | append / mark-cancelled on the vector; stable `id` map | mutation-during-dispatch deferred to the next-message snapshot (§2.1) |
| pattern match (§2.2) | atom-eq + trailing-`.*` prefix-glob; head-name eq; CXPath predicate eval ([`code.md`](../core/code.md) CXPath) | **pure**; the same matcher backs `emit`, `match`, `matches`, `subscribers` filter |
| dispatch order (§4.1) | stable sort by `(−priority, registration-index)` | total order; deterministic |
| re-entrant drain (§4.2) | iterate a FIFO queue, **not** host recursion | re-entrant `emit` enqueues; bounds host stack; `max-cascade-*` cap the queue (§4.4) |
| `[dispatch]` value | accumulate `fired` / `events` / `depth` / `faults` during the drain | the observability record (dry-run + audit reuse `match`) |

Spec is implementation-agnostic; only surface + guarantees are normative. **The
XAP serialized cascade is NOT in this module** — `[$xap:…]` composes `bus` (this
ordered drain) with [`journal.md`](journal.md) (append + hash chain +
fold) and [`authz.md`](authz.md) (PEP) into the §2 commit transaction
([`xap.md`](xap.md) §14, §25.1). A bus is **cheap**: constructing one, subscribing,
and tearing it down is all in-process pointer work, so per-request or per-surface
buses are a normal pattern (a worker owns its bus, §2.1).

## §10. Conformance fixtures (to author on graduation)

Hermetic, in-process (no socket, no clock). **Every matrix ✅ has ≥1 positive
fixture; every justified ❌ a negative fixture.**

Positives: `on` + `emit` delivers to a single subscriber (handler observes the
message); **multiple subscribers fire in priority-then-registration order**
(byte-exact `[dispatch]/fired` sequence); `emit` with **zero matching subscribers →
`[dispatch delivered=0]` VALUE, not `[err]`, not absence** (§2.3); atom-topic match,
**`:order.*` prefix-glob**, head-name match, and **CXPath-predicate match**
(`[?[= /do :refund] [< /amount 50]]`) each select the right subscribers; `topic`
derivation (head+leading-atom, and head-name-only when no atom); **re-entrant
emission queued and drained before the next external message** (a handler that
`emit`s a second message — observe FIFO order in `[dispatch]/events`); `once`
auto-cancels after first delivery; `priority` reorders fire order; **mutation during
dispatch takes effect next message** (an `on` inside a handler does not fire for the
in-flight message); a handler that **`off`s a not-yet-fired peer** removes it from
the current snapshot (§3.3); `off` returns `true` then `false` (idempotent); `match`
/ `matches` dry-run **without firing** (handler side-effect absent); `subscribers`
filtered + unfiltered, in dispatch order; `[?with-open]` auto-close drops
subscriptions; handler **capability effect** flows through (a handler doing a
granted `store.put` succeeds; the bus adds no gate).

Handler-fault policies: `:isolate` (default) — a faulting handler does not stop the
cascade, peers still fire, `[dispatch]/faulted=true`; `:collect` — fault `[err]`s
aggregated into `[dispatch]/faults`; **`:halt` — cascade stops at the fault, peers
do not fire, `emit` propagates the handler's `[err]`** (the XAP-cascade mode).

Negatives: non-callable handler / malformed pattern / non-element message →
`CXER4660`; **concurrent / non-owner `[bus]` use → `CXER4661`**; duplicate
`opts.id` → `CXER4662`; **cyclic handler graph hits `max-cascade-depth` /
`max-cascade-events` → `CXER4663` carrying the partial `[dispatch]`** (proves no
hang); op on a closed bus → `CXER4664`; **`emit sync=false` → `CXER4665`** (the
no-async guard, N-BUS-1); `[?timeout]` wrapping `emit` → inner handler `CXER0260`,
cascade halts; a handler's **capability denial → `CXER0271` at the handler's effect
point** (bus surfaces no code of its own).

## §11. Graduation checklist (executor → user G3)

- [ ] **Governance registry** ([`governance.md`](../process/governance.md) §9.6):
      add `CXER4650–CXER4699 | cx-stdlib/bus | spec/std-lib/bus.md`; re-run the band
      scan (confirm no overlap with http's `CXER4525–4543`; the band sits above it).
- [ ] **Module index + count (see §12).** Add a `bus` row to
      [`spec/std-lib/README.md`](../std-lib/README.md) §3 (Tier-B) and bump the
      module count by **+1** on the then-current count, and the skeleton-test
      assertion + `expected` list in
      `vcx/tests/stdlib_skeleton_test.v` to include `'cx-stdlib/bus'`
      (bus is **not yet a bundled name** — a genuine +1, unlike http's
      reconciliation, §12).
- [ ] **Implement the module** (`stdlib/bus.cx`, or the bundled host path): `bus`/
      `close`/`on`/`off`/`emit`; introspection `subscribers`/`topics`/`match`/
      `topic`/`matches`; the §2.2 matcher (atom + glob + head-name + CXPath); the
      §4.2 FIFO re-entrant drain with the §4.4 caps; the §4.3 `on-fault` policies.
- [ ] Confirm bus's reliance on the §0 in-review amendments survived their G3
      (four-channel model incl. **zero-subscriber-is-a-value**, `[?try]` retirement,
      `CXER0260` cancellation, closeable contract, orthogonality-guard home).
- [ ] **Coordinate the XAP module set.** bus is the ordered-dispatch primitive the
      serialized cascade composes; its sibling drafts
      ([`journal.md`](journal.md), [`authz.md`](authz.md),
      [`session.md`](session.md), [`xap.md`](xap.md))
      build the commit transaction **on top** ([`xap.md`](xap.md) §14, §25.1). Keep
      the boundary in §2.4 stable (bus stays cascade-free).
- [ ] Author §10 fixtures; wire into the gate.
- [ ] Validate repo-relative cross-references render (sibling drafts may not exist
      yet — links resolve on their authoring).
- [ ] Move `spec/02-inprogress/xap/bus.md` → `spec/std-lib/bus.md`
      (user-only G3).

## §12. Module-count reconciliation (normative for the count; no edits made here)

This section states the **count delta**; per Rule G3 it makes **no edits**.

**bus is an ADDITION, not a reconciliation.** Unlike `http` (which corrected a
README 29→30 to match an *already-bundled* name,
[`http.md`](http.md) §12), `cx-stdlib/bus` is **not currently a
bundled name** — it is absent from the skeleton test's `expected` list and from
`spec/std-lib/README.md` §3. So bus is a genuine **+1** at its own graduation:
both the README count **and** the
`stdlib_skeleton_test.v::test_stdlib_surface_enumerates_bundled_subpackages`
assertion (currently 30) **and** its `expected` list (add `'cx-stdlib/bus'`) move
together, in the graduation PR.

| Target (by section/symbol) | Current | Becomes (at graduation) |
|---|---|---|
| `README.md` §3 intro sentence | "enumerates **N** sub-packages" | "**N+1**" |
| `README.md` §3.2 frozen-surface sentence | "The **N-module** … frozen surface" | "**(N+1)-module**" |
| `README.md` §3 Tier-B table | (no `bus` row) | add `\| bus \| in-process pub/sub, synchronous ordered dispatch \| [bus.md](bus.md) \|` |
| `stdlib_skeleton_test.v` — `test_stdlib_surface_enumerates_bundled_subpackages` | asserts **N**, no `'cx-stdlib/bus'` | asserts **N+1**, lists `'cx-stdlib/bus'` |

**Order-independence with the other XAP modules.** Each of the five XAP modules
(`bus`, `journal`, `authz`, `session`, `xap`) is an independent **+1** applied to
whatever the current bundled-name count is when it graduates; the deltas compose in
any order. **No edits are made by this draft** (G3) — the table above is for the
graduation PR. `N` here is the bundled-name count at bus's graduation (30 after
http reconciles, then +1 per prior-graduated sibling).
