# D91a — `cx --version` stamps the front door's commit, with a `core` line (owner: Letter 1 = (a), 2026-09-25)

**Status: RULED (owner, 2026-09-25 ~12:4xZ, in session, on
[#1591](https://github.com/cx-home/cx-private/issues/1591)).** It follows CO-4/#979's
invariant (tag == VERSION == artifact commit) into the provenance headline `cx --version`
prints, once the front door builds by driving `deps/cx-core-code/vcx`'s own Makefile.

## The measurement (the integrator's, 2026-09-25; cited as measured, not inferred)

`CX_COMMIT` in cx-core-code's `vcx/Makefile` is `git -C $(CURDIR)/.. rev-parse --short HEAD`.
The front door's Makefile runs `$(MAKE) -C deps/cx-core-code/vcx DEPS_THIRD_PARTY_PATH=$(CURDIR) …`,
so `$(CURDIR)/..` there is `deps/cx-core-code`, not the front door's own checkout: a `cx` built
from the front door stamps the pin (`416a419`), not the tagged front-door commit. The printer is
`deps/cx-core-code/vcx/cmd/main.v` (`println('  V fork   ${cx_vfork}')`).

## The owner's word, verbatim

"a" — Letter 1 = (a). The three options, verbatim:

> **(a)** `commit` = the front door's HEAD, plus a `core <sha>` line beside the existing `V fork`
> line. One change in cx-core-code's `vcx/Makefile` (the stamp root from a variable the front
> door's Makefile passes; the default unchanged), a cx-core-code push and a pin bump. Long-term:
> tag, VERSION and stamp name one commit in one repository; the core's provenance stays printed;
> R2.2 keeps its meaning. Sonnet, ~0.15 M; lands through K12b's pin bump or a small branch after
> it.
>
> **(b)** keep the pin's commit; document it. Long-term: no shipped binary maps to its release
> tag; every later release inherits that; a bisect from a binary starts in the wrong repository.
>
> **(c)** the front door's commit only, no core line. Long-term: the core's sha is invisible from
> a binary (recoverable only through `deps.cxd` at that commit).
>
> Recommendation: (a).

Recorded: `cx --version`'s `commit` becomes the front door's HEAD, with a `core <sha>` line
beside the `V fork` line; cx-core-code's `vcx/Makefile` takes the stamp root from a variable the
front door's Makefile passes, default unchanged; a cx-core-code push and a pin bump. Goes on the
ledger by the branch that implements it (K14, sonnet, after K12b's pin bump lands so the two do
not race on the cx-core-code pin).

## The rule

1. `commit` names the commit of the repository whose tree the binary was built from: the front
   door's HEAD when built at a tag (or any front-door checkout), the core's own HEAD when built
   core-only (no front door in the tree above it).
2. A `core <sha>` line names the cx-core-code pin beside the existing `V fork` line whenever the
   binary was built from a front door (a core-only build has no front-door pin to name and omits
   it).
3. cx-core-code's `vcx/Makefile` reads its stamp root from a variable (`CX_STAMP_ROOT`, default
   `$(CURDIR)/..` unchanged) so a core-only build keeps stamping its own HEAD as `commit` while a
   front-door build can pass its own checkout root and add the `core` line from the pin's HEAD.
4. The front door's Makefile passes that root on every `$(MAKE) -C deps/cx-core-code/vcx` line.
