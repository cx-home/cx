// program_eval.rs — smoke tests for the cxlib eval_code /
// eval_code_streaming / cx_code_diagram surface. Mirrors what
// the Tier-1 Python + Go bindings cover, scaled to the Rust
// binding (Tier 1 from v0.8.0 per d-2026-05-22-03).
//
// Phase 3.5 dead-code cleanup: `program_diagram` was renamed to
// `cx_code_diagram`. The legacy name is kept as a
// `#[deprecated]` alias in `src/lib.rs` for one cycle; tests bind
// to the canonical v0.8.0 name.

use cxlib::{cx_code_diagram, eval_code, eval_code_streaming};

// cx_code_eval_streaming uses a single-threaded sink model (cabi.v): two
// streaming evaluations running concurrently in one process clobber each
// other's chunk sink. That is the documented v0.8.0 contract (parallel
// streaming is v0.9.0 concurrency work, readiness-rubric §15). Cargo runs
// tests in parallel threads, so the streaming tests below serialize through
// this lock — the streaming FEATURE is exercised; concurrent streaming is
// out of scope and not asserted.
static STREAM_SERIAL: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[test]
fn eval_code_simple_for() {
    let input = "[doc [user [name Alice]] [user [name Bob]]]";
    let program = "[?for [user [name $n]] [yield $n]]";
    let out = eval_code(input, program, "cx").expect("eval_code");
    assert!(out.contains("Alice"), "out should contain Alice: {out}");
    assert!(out.contains("Bob"), "out should contain Bob: {out}");
}

#[test]
fn eval_code_default_target_is_text() {
    let input = "[doc [user [name Alice]]]";
    let program = "[?for [user [name $n]] [yield $n]]";
    let out1 = eval_code(input, program, "").expect("eval_code default");
    let out2 = eval_code(input, program, "text").expect("eval_code text");
    assert_eq!(out1, out2);
}

#[test]
fn eval_code_unknown_target_is_error() {
    let input = "[doc [user [name Alice]]]";
    let program = "[?for [user [name $n]] [yield $n]]";
    let res = eval_code(input, program, "definitely-not-a-target");
    assert!(res.is_err(), "unknown target should be rejected");
}

#[test]
fn eval_code_parse_error_is_error() {
    let res = eval_code("", "[?this-directive-does-not-exist]", "cx");
    assert!(res.is_err(), "unknown directive should fail parse");
}

#[test]
fn eval_code_streaming_concat_equals_oneshot() {
    // Use a [?for $x :in seq] shape (matches the Python + Go streaming
    // contract tests). Pattern-generator [?for] forms without an
    // explicit `:in` source don't yet round-trip through the streaming
    // evaluator — Phase 4.1 follow-up; tracked independently.
    let _serial = STREAM_SERIAL.lock().unwrap_or_else(|e| e.into_inner());
    let input = "";
    let program = "[?for [in $i (10, 20, 30)] [yield [item n=$i]]]";
    let oneshot = eval_code(input, program, "text").expect("oneshot");
    let mut chunks: Vec<u8> = Vec::new();
    eval_code_streaming(input, program, "text", |chunk| {
        chunks.extend_from_slice(chunk);
        Ok(())
    })
    .expect("streaming");
    let streamed = String::from_utf8(chunks).expect("utf8");
    assert_eq!(oneshot, streamed);
}

#[test]
fn eval_code_streaming_callback_abort() {
    let _serial = STREAM_SERIAL.lock().unwrap_or_else(|e| e.into_inner());
    let input = "";
    let program = "[?for [in $i (1, 2, 3)] [yield [item n=$i]]]";
    let res = eval_code_streaming(input, program, "text", |_chunk| {
        Err("user aborted".to_owned())
    });
    assert!(res.is_err(), "callback Err should abort streaming");
}

#[test]
fn program_diagram_mermaid_smoke() {
    let source = "[?for [user [name $n]] [yield $n]]";
    let out = cx_code_diagram(source, "mermaid").expect("diagram");
    assert!(out.contains("flowchart"), "mermaid output should contain 'flowchart': {out}");
    assert!(out.contains("%%cx:"), "diagram should embed source per gate-9 contract: {out}");
}

#[test]
fn program_diagram_unsupported_format_is_error() {
    let source = "[?for [user [name $n]] [yield $n]]";
    let res = cx_code_diagram(source, "definitely-not-a-format");
    assert!(res.is_err(), "unsupported diagram format should error");
}

// ── SAP migration (errors / effects / fp) parity smoke tests ───────────────
//
// The V runner (vcx/tests/code_eval_fixtures_test.v) drives every SAP
// [case id=…] in conformance/code.cxd; the Python + Go bindings mirror the
// SAP subset in their corpus whitelists. The Rust binding is Tier-1 smoke
// (per d-2026-05-22-03) and has no code.cxd corpus runner, so it exercises
// the same new surfaces through eval_code directly — one assertion per SAP
// surface, programs/expected-outputs copied from the conformance fixtures so
// drift is caught here too.

#[test]
fn sap_else_coalesces_err_and_passes_falsey() {
    // §8.13 [?else]: an [err] defaults; a falsey-but-present value passes.
    assert_eq!(eval_code("", "[?else [/ 10 0] 'safe']", "text").unwrap(), "'safe'");
    assert_eq!(eval_code("", "[?else () 'd']", "text").unwrap(), "'d'");
    assert_eq!(eval_code("", "[?else false 'fallback']", "text").unwrap(), "false");
    assert_eq!(eval_code("", "[?else 0 'fallback']", "text").unwrap(), "0");
}

#[test]
fn sap_match_inline_scrutinee_catches_err() {
    // §8.2 [?match] over an inline [err]-valued scrutinee (V1a exemption).
    let out = eval_code(
        "",
        "[?match [/ 10 0] [case [err $e] caught] [else ok]]",
        "text",
    )
    .unwrap();
    assert_eq!(out, "caught");
}

#[test]
fn sap_o1_pattern_grammar_captures_and_type_tests() {
    // O1 uniform [case] grammar: attr capture + a value-kind type-test.
    let cap = eval_code(
        "",
        "[?let [= $r [err code=rate-limited]] [?match $r [case [err @code=$c] {got: $c}] [else other]]]",
        "text",
    )
    .unwrap();
    assert_eq!(cap, "{got: 'rate-limited'}");
    let tt = eval_code(
        "",
        "[?let [= $r 42] [?match $r [case $n::int {int: $n}] [else [other]]]]",
        "text",
    )
    .unwrap();
    assert_eq!(tt, "{int: 42}");
}

#[test]
fn sap_o4_path_distributes_over_sequence() {
    // O4: a path step distributes over a sequence, skipping non-matches.
    let out = eval_code(
        "",
        "[?let [= $s ([a x=1], [a x=2])] [?let [= $q $s/@x] $q]]",
        "text",
    )
    .unwrap();
    assert_eq!(out, "(1, 2)");
}

#[test]
fn sap_pipe_reshape_bare_stages_and_railway() {
    // §8.9 [?pipe]: bare stages thread the value; an upstream [err] short-
    // circuits the rest of the pipe (railway).
    let ok = eval_code(
        "",
        "[?def add1 ($x) [+ $x 1]] [?pipe 5 add1 add1]",
        "text",
    )
    .unwrap();
    assert_eq!(ok, "7");
    let railway = eval_code(
        "",
        "[?def boom ($x) [/ $x 0]] [?def add1 ($x) [+ $x 1]] [?pipe 5 boom add1]",
        "text",
    )
    .unwrap();
    assert!(
        railway.contains("cx-err:CXER0101"),
        "railway short-circuit should surface the upstream err value: {railway}"
    );
}

#[test]
fn sap_try_surface_retired_is_error() {
    // §2.5: the try/catch directive and the for-comprehension on-error clause
    // are retired — each now raises the unknown-directive / tombstone CXER0100.
    let try_res = eval_code("", "[?try [/ 10 0] [catch $err 0]]", "text");
    assert!(try_res.is_err(), "the retired try directive must be rejected");
}

#[test]
fn sap_null_totality_never_crashes() {
    // §1.0 null-totality: a null operand yields a clean err value or a defined
    // value — never a host crash. eval_code must return (Ok or Err), not panic.
    let arith = eval_code("", "[+ null 5]", "text");
    assert!(arith.is_ok() || arith.is_err());
    let eq = eval_code("", "[= null null]", "text").unwrap();
    assert_eq!(eq, "true");
    let count = eval_code("", "[$count null]", "text").unwrap();
    assert_eq!(count, "1");
}

#[test]
fn sap_concurrency_raii_and_cancel_revokes_caps() {
    // §10.5.7.1 RAII: [?with-open] over an [?async] future cancels-and-joins
    // on scope exit; a completed body's value is preserved.
    let raii = eval_code("", "[?with-open [?async [+ 21 21]] $f [?await $f]]", "text").unwrap();
    assert_eq!(raii, "42");
    // §10.5.7.2 cancel-revokes-caps: a cancelled task hitting a cancellation
    // point reports CXER0260 (cancel-check ▷ cap-check precedence).
    let cancel = eval_code(
        "",
        "[?let [= $f [?async [?check-cancel]]] [?let [= $_ [?cancel $f]] [?match [?await $f] [case [err @code='cx-err:CXER0260'] [cancelled]] [else [other]]]]]",
        "text",
    )
    .unwrap();
    assert_eq!(cancel, "[cancelled]");
}
