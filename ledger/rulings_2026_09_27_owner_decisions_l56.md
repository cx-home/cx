# Owner decision 2026-09-27 (afternoon) — Letter 56: the public-history replacements file must survive its own pass (PUBFIX-1)

**Status: RULED (owner, 2026-09-27 ~15:1xZ, in session, on the letter posted on
[#1591](https://github.com/cx-home/cx-private/issues/1591) at 15:0xZ; D83a, RS-33, #1669, Letter 12 = (a)).**

## The owner's word, verbatim

"l56a"

## PUBFIX-1 — fix first, then REFRESH-5 (L56 = (a))

REFRESH-4 measured that the #1669 replace-text pass rewrites `scripts/public_history_replacements.txt`
itself in the public history — its rows are the literals the pass replaces — so the public copy reads
redacted, `check-public-history-replace`'s self-test fails in the public clone (`make test` EXIT=2, the
only red step) and main's tree is no longer the stripped tree's. The fix comes first, in cx-private: the
expressions file is written in a form the pass cannot match against itself (filter-repo's `regex:` rows,
or the values split so that no row contains a whole literal), the gate's self-test adjusted, and one
fixture proves the public copy survives the pass byte-identical. Then REFRESH-5 re-prepares the
artifact from a head carrying the fix, and the push is forced with a lease on the live main, as
Letter 12 (a) allows. Rejected: (b) pushing now and fixing later — a red `make test` on the public
main; (c) dropping the file from the public path set — a gate that passes by absence.
