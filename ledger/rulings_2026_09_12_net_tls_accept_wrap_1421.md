# RULED: 1421-a — the server-role TLS upgrade on an accepted connection, and the `STARTTLS` offer it unblocks

**Integrator, 2026-09-12, under the owner's delegation of 2026-09-09; pulled into v0.18 by
INT-2.** Issue **#1421** (`area:cx-stdlib`, `prio:high`), raised by the `cx-stdlib/smtp` M1
implementation branch (#1085 M1) on 2026-09-11: a server cannot upgrade an already-accepted
plaintext connection to TLS, so SMTP `STARTTLS` (RFC 3207) and IMAP `STARTTLS` (RFC 9051
§6.2.1) cannot be offered — an MX on port 25 under `tls=:required` cannot receive mail at all.

| Id | The question | Ruled |
|---|---|---|
| **1421-a** | the server-role counterpart of `tls-wrap` | `net` performs the **server side of the TLS handshake over an already-accepted plaintext stream socket**, taking that socket and the server's `cert`/`key` (plus an optional client CA for mutual TLS), returning the TLS connection and consuming the underlying one. Refusals stay in `net`'s own `CXER45xx` band — handshake failure, missing cert/key, an already-TLS connection — and NO new code is allocated |
| **1421-a-1** | the verb's name | the verb is the already-approved **`net:tls-accept`**, not a new `tls-accept-wrap` — see "The name" below |
| **1421-b** | `smtp` and `imap` servers | a `tcp://` bind carrying `opts.tls` **offers `STARTTLS`**: advertise it, accept the command, upgrade the connection, reset the session state as each RFC requires (smtp: discard EHLO state; imap: pre-auth only), and refuse cleartext `AUTH`/`LOGIN` under `tls=:required` until the upgrade has happened. The bind-time refusals `CXER5706` / `CXER5806` that named this gap are **removed**; their cases become the `STARTTLS` accept cases |

## The name (1421-a-1) — what 1421-a's `tls-accept-wrap` becomes, and why

The decision as written named a NEW verb, `net:tls-accept-wrap`, "the server-role counterpart
of `tls-wrap` (net.md §3.6)". That name came from #1421's own text, which was written from the
V fork's side of the seam ("there is no `tls-accept-wrap`") and did not read §3.6 first.

`net.md` §3.6 is titled **"TLS — client + server upgrade"** and already declares, beside
`tls-wrap`:

```
[?def tls-accept scope=public impure [returns element] ($sock::element $opts::map) ...]
```

and states of BOTH that they "**consume** the underlying socket (→ `state="consumed"`); the
secure socket inherits `fd`/deadlines/options; upgrade at a clean protocol boundary". §7's
transport matrix gives the row `tls-wrap`/`tls-accept` a **✅⁵** in the **tcp** column
("upgradable") and a **— ⁶** in the **tls** column ("already secured"), and §3.6a calls its
DTLS server verb "the datagram counterpart of **stream `tls-accept`**". `stdlib/net.cx`
carries the `?def` and its `fn-doc` ("Perform a **server** TLS (or DTLS) handshake over an
existing socket, consuming it for a secure one"), `security.md` §2.1 carries the
`net-tls-accept` effect row, and `conformance/stdlib/net.cxd` carries `net-049`.

So the approved spec already HAS the server-role stream verb; what #1421 measured is that it
is a shim — `net_handle_op_socket` returns its argument. Adding `tls-accept-wrap` beside it
would give one operation two public names and leave the specified one a dead stub, which the
orthogonality objective forbids and which no reader could later untangle. **1421-a's substance
is implemented under the name the spec already approved: `net:tls-accept`.** Nothing in 1421-a
changes but the spelling; `tls-accept-wrap` is never introduced, and the prose that cited it
(`smtp.md` §3.6, the two wire-file headers, 1085-c-1's row) is corrected to cite `tls-accept`.

## §1. `net:tls-accept` — the surface (net.md §3.6, unchanged in shape)

`[$net:tls-accept $sock $tls-map]` where `$sock` is a **connected, plaintext, stream** socket
this process accepted (or dialed), and `$tls-map` is the §3.6 `tls::map` read in its SERVER
sense:

- `cert` / `key` — REQUIRED, PEM (content when `in-memory` is true, else a path, exactly as
  `listen-tls` reads them). Absent → `cx-err:CXER4514 E_NET_TLS_CONFIG`.
- `ca` — the client CA for mutual TLS. Present ⇒ a client certificate is REQUIRED and verified
  against it; a client that presents none, or one that does not chain, fails the handshake →
  `cx-err:CXER4512 E_NET_TLS_HANDSHAKE_FAILED`. Absent ⇒ no certificate is requested.
- `in-memory` — `cert`/`key`/`ca` are PEM CONTENT rather than paths (the `listen-tls` spelling,
  #180/#199: a key injected from the environment never touches disk).
- `server-name` is **not** read: there is no SNI to send and nothing to verify a name against.
  This is the asymmetry with `tls-wrap`, whose `server-name` is REQUIRED under `verify=true`.

**Consumption (§3.6, verbatim for both verbs).** The plaintext socket becomes
`state="consumed"` and every later op on it is `cx-err:CXER4515 E_NET_HANDLE_CLOSED`; the
returned `[socket … transport='tls' secure=true]` owns the file descriptor.

**Refusals — no new codes.** §3.6a's rule ("No new band entries") holds here too; the
`CXER4500–CXER4524` band is unchanged and `governance.md` §9.6's row is annotated, not
extended:

| Raised when | Code |
|---|---|
| handshake failure (chain, version, cipher, ALPN, **client cert under mTLS**) | `cx-err:CXER4512` |
| `cert` or `key` missing, or unreadable/unparseable | `cx-err:CXER4514` |
| the handle names no live socket, or one already consumed/closed | `cx-err:CXER4515` |
| the handle is a **listener**, a **datagram** socket, or **already TLS** | `cx-err:CXER4522` |

The already-TLS refusal is `CXER4522 E_NET_ARG_INVALID` and not a new code because §7's matrix
already says the answer: the `tls` column's cell for this row is "— ⁶ already secured", i.e.
the verb does not apply to that transport — the same shape as "`accept` on the wrong socket
kind", which is what 4522 is for. A second TLS layer over a TLS socket is not a degraded
success to be tolerated; it is a caller bug, and it is refused loudly.

**Ordering (§4.1, fail-closed).** The `net` capability guard runs FIRST, before the config is
read and before the handle is resolved, so an ungranted caller learns only `CXER0271` — never
whether its cert parsed or whether its socket was already secure.

## §2. The V-fork change (V-only, CX-agnostic — the standing rule)

`net.mbedtls` exposed `SSLConn.connect` (client role over an existing `TcpConn`) and
`SSLListener.accept` (server role over a socket the listener itself bound). The missing third
combination — **server role over an existing `TcpConn`** — is added in
`vlib/net/mbedtls/ssl_connection.c.v`:

- `SSLConnectConfig.is_server` — selects `MBEDTLS_SSL_IS_SERVER` in `SSLConn.init`, and with it
  the server authmode (`VERIFY_REQUIRED` under `validate`, i.e. mTLS; `VERIFY_NONE` otherwise,
  so a plain server never sends a `CertificateRequest` it will not check).
- `new_ssl_server_conn(config)` — the server-role constructor; refuses a config with no
  `cert`/`cert_key` the way `SSLListener.init` does.
- `SSLConn.accept_conn(mut tcp_conn)` — the handshake itself, the mirror of `connect` minus
  `mbedtls_ssl_set_hostname`, retrying on `WANT_READ`/`WANT_WRITE` as mbedTLS requires.

It is a V API addition with no CX in it, pinned by sha in `third_party/v` with its
`v_fork_register.cxd` row (a pin bump without the row reds `check-v-fork`).

## §3. `smtp` and `imap` — the `STARTTLS` offer (1421-b)

**smtp.** The pure server core already implements RFC 3207 end to end — the `250-STARTTLS`
advertisement while unprotected, `STARTTLS` with no argument, the 554 refusal of octets
buffered across the upgrade (CVE-2011-0411), the 530 refusal of `AUTH` before it, and
`action=upgrade-tls` on the step. Only two things change: `smtp_validate_bind` stops refusing a
`tcp://` bind whose policy is not `tls=:none`, and the driver's `upgrade-tls` arm stops
answering `454` and performs the upgrade. The EHLO-state reset RFC 3207 §4.2 requires is the
pure core's `server-init`-equivalent transition, driven by the driver re-initializing the
session over the upgraded socket.

**imap.** The pure server core refuses `STARTTLS` and never advertises it; that is what
changes. `CAPABILITY` advertises `STARTTLS` while the connection is unprotected AND the
listener holds a server identity; the command is answered `OK` and emits the upgrade action;
on upgrade the session **discards every capability and state it had learned** and returns to
*not authenticated* (RFC 9051 §6.2.1 — the server MUST discard knowledge obtained before
`STARTTLS`), and `LOGIN`/`AUTHENTICATE` stay refused on an unprotected connection under every
`tls=` setting.

**Under `tls=:required`**, a cleartext credential is refused until the upgrade has happened —
this is unchanged behavior in both modules and is now reachable, because a `tcp://` bind under
`:required` exists.

## §4. Placement (OL-15)

| | |
|---|---|
| ring | `net` is **Ring 2** (`vcx/platform/`) |
| code | `vcx/platform/stdlib_net.v` (the server-role upgrade, beside `net_listen_tls_real`); `vcx/platform/stdlib_smtp_wire.v` and `vcx/platform/stdlib_imap_wire.v` (the drivers); `vcx/code/stdlib_imap_server.v` (the pure `STARTTLS` fold) |
| spec | `spec/03-approved/std-lib/net.md` §3.6; `spec/03-approved/std-lib/smtp.md` §3.6; `spec/03-approved/std-lib/imap.md` §3.7/§6.2; `spec/03-approved/process/governance.md` §9.6 |
| namespace | `net:` — no new namespace; no new module |
| corpus | `conformance/stdlib/net.cxd`, `conformance/stdlib/smtp.cxd`, `conformance/stdlib/imap.cxd` |
| fork | `third_party/v` `vlib/net/mbedtls/ssl_connection.c.v` + `vcx/tests/v_fork_register.cxd` |

## §5. Graded by

- **`conformance/stdlib/net.cxd`** — the capability-gate ordering cases: `tls-accept` with a
  full `cert`/`key` map, and `tls-accept` on an already-TLS socket, both `CXER0271` under the
  empty grant, proving the guard precedes both the config read and the transport check. The
  cert/key, already-TLS and handshake refusals themselves need the grant and a socket, so they
  are measured where they are reachable and cited here rather than left implicit.
- **`vcx/tests/net_real_socket_test.v`** — a cx server that `accept`s plaintext, exchanges a
  cleartext line, `tls-accept`s and exchanges over the upgraded connection against a real
  mbedTLS client; the consumed-socket refusal; the missing-cert/key refusal; the already-TLS
  refusal; and a mutual-TLS handshake refused when the client presents no certificate.
- **`vcx/tests/smtp_real_socket_test.v`** — a `tcp://` bind with `opts.tls`: `EHLO` sees
  `250-STARTTLS`, `STARTTLS` is accepted, the upgraded session `AUTH`s and delivers a message;
  and `AUTH` before the upgrade under `tls=:required` is refused.
- **`vcx/tests/imap_real_socket_test.v`** — a `tcp://` bind with `opts.tls`: `CAPABILITY` lists
  `STARTTLS`, the upgrade is accepted, the upgraded session `LOGIN`s and `SELECT`s a mailbox;
  and `LOGIN` before the upgrade is refused.
- **the V fork's own test** — `vlib/net/mbedtls/mbedtls_accept_conn_test.v`, the server-role
  handshake over an accepted `TcpConn` against `SSLConn.dial`.
