//! Rust store-client parity (cxlib::store::StoreClient) over THE store wire.
//!
//! BEHAVIORAL test: spawns a real `cx store-serve` daemon over loopback (a
//! mem:// store served over the XSP store profile, floor policy) and drives the
//! full Layer-1 CRUD surface through StoreClient, proving the wrapper drives
//! the audited store client in the CX CORE end-to-end (put → get → exists →
//! list → query → iter → delete → exists) — the same round trip the Python and
//! Go clients cover. Stream-4 S3 retired the CSRP transport — the wire here is
//! cx-store+xsp:// and authority is XSP-AUTH (grants deny/admit lane included).
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

// RFC 8032 TEST-vector identities (throwaway — never real keys).
const HOST_DID: &str = "did:key:z6MkiaMbhXHNA4eJVCCj8dbzKzTgYDKf6crKgHVHid1F1WCT";
const HOST_SEED_HEX: &str = "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb";
const CLIENT_DID: &str = "did:key:z6MktwupdmLXVVqTzCw4i46r4uGyosGXRnR3XjN4Zq7oMMsw";
const CLIENT_SEED_HEX: &str = "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60";
const HOST_SEED_ENV: &str = "CX_RUST_STORE_TEST_SEED";
const CLIENT_SEED_ENV: &str = "CX_RUST_STORE_CLIENT_SEED";

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

/// Spawn `cx store-serve` with the [xsp] profile listener; return
/// (guard, xsp_port). `policy` is the profile policy block; `grants` an
/// optional [grants …] block (deny-by-default authority when present).
fn spawn_xsp(store_url: &str, policy: &str, grants: &str) -> Option<(DaemonGuard, u16)> {
    let bin = cx_bin();
    if !bin.exists() {
        eprintln!("SKIP: cx binary not found at {} — run `make build-vcx`", bin.display());
        return None;
    }
    let bport = free_port();
    let xport = free_port();
    let cfg = std::env::temp_dir().join(format!("cxstore_rust_{xport}.cx"));
    std::fs::write(
        &cfg,
        format!(
            "[cxstore-service\n  [bind addr=\"127.0.0.1:{bport}\"]\n  [stores\n    [store name=\"t\" url=\"{store_url}\"]]\n  [xsp enabled=true addr=\"127.0.0.1:{xport}\"\n    [identity did=\"{HOST_DID}\" seed-env=\"{HOST_SEED_ENV}\"]{policy}{grants}]]\n"
        ),
    )
    .unwrap();
    let child = match Command::new(&bin)
        .args([
            "store-serve",
            "--config",
            cfg.to_str().unwrap(),
            "--allow-env",
            &format!("--allow-net=127.0.0.1:{bport}"),
            &format!("--allow-net=127.0.0.1:{xport}"),
        ])
        .env(HOST_SEED_ENV, HOST_SEED_HEX)
        .spawn()
    {
        Ok(c) => c,
        Err(e) if e.kind() == ErrorKind::NotFound => {
            eprintln!("SKIP: cannot exec cx binary");
            return None;
        }
        Err(e) => panic!("spawn cx store-serve: {e}"),
    };
    Some((DaemonGuard(child), xport))
}

/// Poll list_docs on `client` until the daemon answers.
fn wait_ready(client: &StoreClient) {
    let deadline = Instant::now() + Duration::from_secs(8);
    while Instant::now() < deadline {
        if client.list_docs().is_ok() {
            return;
        }
        std::thread::sleep(Duration::from_millis(100));
    }
    panic!("daemon never became ready");
}

#[test]
fn store_client_round_trip() {
    let _g = serial();
    let Some((_guard, xport)) =
        spawn_xsp("mem://rust-client", "\n    [policy mode=floor floor=\"guest\"]", "")
    else {
        return;
    };
    let c = StoreClient::new(&format!("cx-store+xsp://127.0.0.1:{xport}/t/"), None).unwrap();
    wait_ready(&c);

    let h = c.put_doc_text("[note [body \"rust-client-roundtrip\"]]").unwrap();
    // I1 identity epoch: content addresses are TAGGED — sha2-256:<64hex>.
    let hex = h.strip_prefix("sha2-256:")
        .unwrap_or_else(|| panic!("put returns tagged sha2-256:<64hex> address, got {h:?}"));
    assert!(
        hex.len() == 64 && hex.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()),
        "put returns tagged sha2-256:<64hex> address, got {h:?}"
    );

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

#[test]
fn store_client_missing_hash_errors() {
    let _g = serial();
    let Some((_guard, xport)) =
        spawn_xsp("mem://rust-client-missing", "\n    [policy mode=floor floor=\"guest\"]", "")
    else {
        return;
    };
    let c = StoreClient::new(&format!("cx-store+xsp://127.0.0.1:{xport}/t/"), None).unwrap();
    wait_ready(&c);
    // Well-formed (tagged, I1) but absent address — must error, not
    // return empty.
    let missing = format!("sha2-256:{}", "0".repeat(64));
    assert!(c.get_doc_text(&missing).is_err(), "missing hash must error, not return empty");
}

#[test]
fn store_client_retired_scheme_rejected() {
    // Stream-4 S3: the CSRP scheme tokens are retired — the façade refuses
    // them up front with the pointer to the live wire.
    assert!(StoreClient::new("cx-store+http://127.0.0.1:1/t/", None).is_err());
}

#[test]
fn store_client_authority() {
    // XSP-AUTH parity: with [grants …] configured (mutual policy) an anonymous
    // client is refused, and the granted DID (identity via open-opts
    // did/seed-env) round-trips — the caller can branch on the structured
    // CxError (#197).
    let _g = serial();
    let grants = format!("\n    [grants [grant did=\"{CLIENT_DID}\" caps=\"read write delete\"]]");
    let Some((_guard, xport)) = spawn_xsp("mem://rust-authz", "", &grants) else { return };
    std::env::set_var(CLIENT_SEED_ENV, CLIENT_SEED_HEX);
    let good = StoreClient::new(
        &format!("cx-store+xsp://127.0.0.1:{xport}/t/"),
        Some((CLIENT_DID, CLIENT_SEED_ENV)),
    )
    .unwrap();
    wait_ready(&good);
    let h = good.put_doc_text("[note [body \"authz-ok\"]]").unwrap();
    assert!(good.get_doc_text(&h).unwrap().contains("authz-ok"));
    // anonymous against the mutual daemon: refused, surfaced as CxError.
    let anon = StoreClient::new(&format!("cx-store+xsp://127.0.0.1:{xport}/t/"), None).unwrap();
    let err: CxError = anon.list_docs().unwrap_err();
    assert!(!err.code.is_empty(), "anonymous refusal carries a structured code, got {err:?}");
}
