# Rulings 2026-08-19 — ORIEL developer guide + storefront packaging (#787 follow-ons)

Owner replied **"1a 2b"** to the two-question packet posed at the W23–W25
session close (Fable 5 flagship session, after the arc completed and the
integration session took the branch).

## 1a — the ORIEL developer guide: file now, draft in a dedicated session

A guide teaching "build a surface the ORIEL way" — feature doc → surface
doc → zero view code → the six-instrument harness — is FILED as its own
tracker issue and drafted in a dedicated docs session, now, while the
material is fresh. The #826 docs-restructure campaign integrates the
finished doc into its ring/nav IA **by name** (specs stay loosely coupled;
no §-number coupling), rather than the guide queueing behind #826's seven
remaining concept arcs.

**Owner requirement carried into the acceptance criteria: the guide MUST
include quickstart test/demo steps** — boot the store, run every
instrument with exact grant flags, and the three live demos (two-tab badge
push; open-drawer refetch; browser+terminal shared shopper via
`CX_UX_SID`) as copy-paste steps.

Rejected: (b) writing it inside #826 (weeks behind the concept arcs);
(c) leaving the wave READMEs to serve (decision records are not
teaching documents, and reference knowledge rots in records).

## 2b — ORIEL is promoted IN-REPO to the reference-XAP home

ORIEL the XAP leaves `design/787/store/` (campaign working papers) for the
repo's reference-XAP location — the precedent is
`spec/03-approved/xap/demos/` (d3-guestbook-web) — versioned and CI-tested
against the exact packs it exercises: the six instruments (drive, keys,
voice, nokernel, diff, bench) become its test lane. **Public exposure
remains a separate, later allowlist decision** on the cx-home/cx mirror —
promotion in-repo does not publish.

**Timing:** at the 0.16.0 cut, or with #867's implementation (whose
acceptance already names ORIEL) — whichever is scheduled first.

Rejected: (a) staying in `design/787/` (a reference nobody is pointed at,
in working-paper territory); (c) its own repo (forks the harness away from
the packs it exists to prove, pins binaries, fights the one-checkout and
dog-fooding disciplines).

Separate track, untouched by this ruling: the UX packs' x/ → `cx-stdlib`
ring graduation continues to ride per-pack G3 spec approval (D3).
