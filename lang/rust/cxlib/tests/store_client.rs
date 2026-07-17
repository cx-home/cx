//! Phase 2 (#105) — Rust CSRP client parity (cxlib::store::StoreClient).
//!
//! BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a
//! mem:// store, auth open) and drives the full Layer-1 CRUD surface through
//! StoreClient, proving the wrapper drives the audited cx-store:// core client
//! end-to-end (put → get → exists → list → delete → exists) — the same round
//! trip the Python and Go clients cover.
//!
//! No Docker; the daemon is granted only loopback net. Skips when the cx binary
//! is absent (run `make build-vcx`).

use std::io::ErrorKind;
use std::net::TcpListener;
use std::path::PathBuf;
use std::process::{Child, Command};
use std::sync::{Mutex, MutexGuard, OnceLock};
use std::time::{Duration, Instant};

// These are integration tests: each spawns a real `cx store-serve` daemon and
// drives it through the in-process libcx client (eval_code_caps via FFI). cargo
// runs #[test] fns in PARALLEL by default, which would drive several in-process
// clients concurrently — the Python (unittest) and Go (in-package) suites run
// serially, so we match that here with a shared lock. It keeps these daemon-owning
// tests one-at-a-time (they each spin up ports/processes) without a `serial_test`
// dependency. Poisoning is ignored (a panicking test still releases the lock).
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(())).lock().unwrap_or_else(|e| e.into_inner())
}

use cxlib::store::{CxError, StoreClient};

fn cx_bin() -> PathBuf {
    // tests run from the crate dir lang/rust/cxlib
    let mut p = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    p.push("../../../vcx/target/cx");
    p
}

fn free_port() -> u16 {
    TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap().port()
}

/// Kill the daemon when the guard drops, even on test failure/panic.
struct DaemonGuard(Child);
impl Drop for DaemonGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn spawn(store_url: &str) -> Option<(DaemonGuard, StoreClient)> {
    let bin = cx_bin();
    if !bin.exists() {
        eprintln!("SKIP: cx binary not found at {} — run `make build-vcx`", bin.display());
        return None;
    }
    let port = free_port();
    let dir = std::env::temp_dir();
    let cfg = dir.join(format!("cxstore_rust_{port}.cx"));
    std::fs::write(
        &cfg,
        format!(
            "[cxstore-service\n  [bind addr=\"127.0.0.1:{port}\"]\n  [stores\n    [store name=\"t\" url=\"{store_url}\"]]]\n"
        ),
    )
    .unwrap();
    let child = Command::new(&bin)
        .args(["store-serve", "--config", cfg.to_str().unwrap(),
               &format!("--allow-net=127.0.0.1:{port}")])
        .spawn();
    let child = match child {
        Ok(c) => c,
        Err(e) if e.kind() == ErrorKind::NotFound => {
            eprintln!("SKIP: cannot exec cx binary");
            return None;
        }
        Err(e) => panic!("spawn cx store-serve: {e}"),
    };
    let guard = DaemonGuard(child);
    let client = StoreClient::new(&format!("cx-store+http://127.0.0.1:{port}/t/"), None).unwrap();
    // wait-ready: poll list_docs until the daemon answers.
    let deadline = Instant::now() + Duration::from_secs(6);
    while Instant::now() < deadline {
        if client.list_docs().is_ok() {
            return Some((guard, client));
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    panic!("daemon never became ready");
}

#[test]
fn store_client_round_trip() {
    let _g = serial();
    let Some((_guard, c)) = spawn("mem://rust-client") else { return };

    let h = c.put_doc_text("[note [body \"rust-client-roundtrip\"]]").unwrap();
    assert_eq!(h.len(), 64, "put returns a 64-hex hash, got {h:?}");

    let got = c.get_doc_text(&h).unwrap();
    assert!(got.contains("rust-client-roundtrip"), "doc body did not round-trip: {got:?}");

    assert!(c.exists(&h).unwrap(), "exists true before delete");
    assert!(c.list_docs().unwrap().contains(&h), "list_docs includes the stored hash");

    // §6.1 query / iter — server-side pushdown, not a client-side scan.
    let h2 = c.put_doc_text("[note [title \"q\"] [body \"second\"]]").unwrap();
    assert!(c.query("//title").unwrap().contains(&h2), "query //title matches the titled doc server-side");
    let iterated = c.iter_docs().unwrap();
    assert!(iterated.contains(&h) && iterated.contains(&h2), "iter_docs enumerates both docs: {iterated:?}");
    let _ = c.delete_doc(&h2);

    assert!(c.delete_doc(&h).unwrap(), "delete reports success");
    assert!(!c.exists(&h).unwrap(), "exists false after delete");
}

/// Spawn an auth-ENFORCING daemon (one static bearer token → reader+writer on the
/// "t" store) and return (guard, port). The secret-hash is sha256("s3cr3t-good").
fn spawn_auth(store_url: &str) -> Option<(DaemonGuard, u16)> {
    let bin = cx_bin();
    if !bin.exists() {
        eprintln!("SKIP: cx binary not found at {} — run `make build-vcx`", bin.display());
        return None;
    }
    let port = free_port();
    let cfg = std::env::temp_dir().join(format!("cxstore_rust_auth_{port}.cx"));
    let secret_hash = "51e2a41fd508a03ac236aaa471a419f03d0960fefbbfae022534df56f98c39ef";
    std::fs::write(
        &cfg,
        format!(
            "[cxstore-service\n  [bind addr=\"127.0.0.1:{port}\"]\n  [auth\n    [static\n      [token id=\"t1\" secret-hash=\"sha256:{secret_hash}\" roles=\"reader writer\" tenant=\"t\"]]]\n  [stores\n    [store name=\"t\" url=\"{store_url}\"]]]\n"
        ),
    )
    .unwrap();
    let child = match Command::new(&bin)
        .args(["store-serve", "--config", cfg.to_str().unwrap(),
               &format!("--allow-net=127.0.0.1:{port}")])
        .spawn()
    {
        Ok(c) => c,
        Err(e) if e.kind() == ErrorKind::NotFound => return None,
        Err(e) => panic!("spawn cx store-serve: {e}"),
    };
    let guard = DaemonGuard(child);
    // the RIGHT token confirms the daemon is up + auth works.
    let good = StoreClient::new(&format!("cx-store+http://127.0.0.1:{port}/t/"), Some("s3cr3t-good")).unwrap();
    let deadline = Instant::now() + Duration::from_secs(6);
    while Instant::now() < deadline {
        if good.list_docs().is_ok() {
            return Some((guard, port));
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    panic!("auth daemon never became ready with the good token");
}

#[test]
fn store_client_wrong_token_auth_error() {
    // §6.1 parity + #197: a wrong bearer token surfaces a structured CxError, not a
    // silent success — and the caller can branch on the stable `code`.
    let _g = serial();
    let Some((_guard, port)) = spawn_auth("mem://rust-auth") else { return };
    let bad = StoreClient::new(&format!("cx-store+http://127.0.0.1:{port}/t/"), Some("wrong-token")).unwrap();
    let err: CxError = bad.list_docs().unwrap_err();
    assert!(
        err.code == "cx-err:CXER1131" || err.code == "cx-err:CXER1702",
        "wrong token must map to an auth code, got {:?}",
        err.code
    );
}

#[test]
fn store_client_missing_hash_errors() {
    let _g = serial();
    let Some((_guard, c)) = spawn("mem://rust-client-missing") else { return };
    let missing = "0".repeat(64);
    assert!(c.get_doc_text(&missing).is_err(), "missing hash must error, not return empty");
}
