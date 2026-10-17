# Owner decision 2026-10-15: P-256 signing on fiat-crypto in the V fork (ECSIG-1)

**Status: RULED (owner, via the integrator on STREAMS/state/claims.txt, 2026-10-15 22:41:09Z; recorded by gaps2 from that RULING line, verbatim below the heading, on the integrator's RULING to gaps2 of 2026-10-17 00:09:22Z).** It answers gaps2's ASK of 2026-10-15 16:0xZ on cx-home/v#39 (the TLS handshake against Go: the P-256 signature is the largest share of the handshake profile). Option (a), taken: vendor fiat-crypto's P-256 into the fork. The download is DL-39: the owner said yes in chat, and the integrator fetched the files (NOTE 2026-10-15 22:44:19Z). Issue: cx-home/v#39.

## ECSIG-1 — (a): vendor fiat-crypto P-256 into the V fork, the download approved, the upstream commit pinned with its license, one fork commit with CI 3/3; the measure is the TLS handshake cell of the #1935 hello-server row

> RULING owner 2026-10-15T22:41:09Z (via integrator) ECSIG-1 = (a): cx-home/v#39 P-256 signing — vendor fiat-crypto P-256 into the fork (the download is approved by this ruling; pin the upstream commit, keep its license file, one fork commit + CI 3/3). gaps2 holds the item: after the natv bump (6), its own fork bump + gate; the TLS handshake cell of the #1935 hello-server row is the measure (PERF-EVID, cx vs Go).

Where it lands: the fork's thirdparty/fiat-p256 holds mit-plv/fiat-crypto at 64e8f2791b byte for byte (p256_64.c, p256_scalar_64.c), with its license files (LICENSE-MIT, LICENSE-APACHE, LICENSE-BSD-1, COPYRIGHT, AUTHORS). Fork commits: faa33c30ee (the vendored code) and e1eeffdbe4 (the license files; V's .gitignore had dropped the extensionless ones). The cx-private pin is dafeffc0f, which landed as f43dd9b6f, as one fork bump together with cx-home/v#22. vgc under msvc rides it as d08976b286 and c4aba36d8a; fork CI vgc 38873981826 was green on all four rows. cx-home/v#39 stays open until its TLS handshake rows against Go meet the bar.

Cites: d08976b286, dafeffc0f, f43dd9b6f.
