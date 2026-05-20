//! v0.7.0 evaluator-surface smoke tests through the Rust binding.
//! Per spec/v0_7_0_status.md H4. Cross-binding parity sanity check;
//! the V conformance runner against conformance/eval.txt is the
//! authoritative per-feature gate.

fn ev(doc: &str, prog: &str) -> String {
    cxlib::eval_cxl(doc, prog, "").expect("eval_cxl")
}

#[test]
fn let_positional() {
    assert_eq!(ev("[product price=12]", "[?let [v, @price, [?=v]]]"), "12");
}

#[test]
fn let_labeled() {
    assert_eq!(
        ev("[product name=Pocket]", "[?let g :be @name :return [?=g]]"),
        "Pocket"
    );
}

#[test]
fn flwor_where() {
    assert_eq!(
        ev(
            "[p [v s=A in=1] [v s=B in=0] [v s=C in=2]]",
            "[?for x :in //v :where x/@in > 0 :return [?=x/@s];]"
        ),
        "A;C;"
    );
}

#[test]
fn flwor_order_by() {
    assert_eq!(
        ev(
            "[p [v s=C] [v s=A] [v s=B]]",
            "[?for x :in //v :order-by x/@s :return [?=x/@s];]"
        ),
        "A;B;C;"
    );
}

#[test]
fn for_tumbling() {
    assert_eq!(
        ev(
            "[r [v n=1] [v n=2] [v n=3] [v n=4] [v n=5]]",
            "[?for-tumbling w :in //v :size 2 :return [?for x :in w :return [?=x/@n]];]"
        ),
        "12;34;5;"
    );
}

#[test]
fn fn_and_apply() {
    assert_eq!(
        ev(
            "[p]",
            "[?let dbl :be [?fn :params [n] :body [?=n][?=n]] :return [?=[?apply [dbl, 'X']]]]"
        ),
        "XX"
    );
}

#[test]
fn partial_middle_placeholder() {
    assert_eq!(
        ev(
            "[p]",
            "[?let f :be [?partial [[?fn-ref [concat, 2]], [?_], '!']] :return [?=[?apply [f, 'hi']]]]"
        ),
        "hi!"
    );
}

#[test]
fn try_multi_catch() {
    assert_eq!(
        ev(
            "[p]",
            "[?try [[?error ['FORG0006', 'wrong type']], [FOAR*, math], [FORG*, generic], [*, other]]]"
        ),
        "generic"
    );
}

#[test]
fn parent_axis() {
    assert_eq!(
        ev(
            "[root [outer tag=O [inner n=42]]]",
            "[?for x :in //inner/parent::* :return [?=x/@tag];]"
        ),
        "O;"
    );
}

#[test]
fn following_sibling() {
    assert_eq!(
        ev(
            "[r [a n=1] [b n=2] [c n=3]]",
            "[?for x :in //a/following-sibling::* :return [?=x/@n];]"
        ),
        "2;3;"
    );
}

#[test]
fn op_pipeline() {
    assert_eq!(ev("[p name=alice]", "[?=@name |> upper]"), "ALICE");
}

#[test]
fn op_to_range() {
    assert_eq!(ev("[p]", "[?for x :in 1 to 4 :return [?=x];]"), "1;2;3;4;");
}

#[test]
fn op_string_concat() {
    assert_eq!(
        ev("[u first=Alice last=Smith]", "[?=@first || '-' || @last]"),
        "Alice-Smith"
    );
}

#[test]
fn attr_value_interpolation() {
    assert_eq!(
        ev(
            "[p [c cid=42 name=Joe]]",
            "[?for c :in //c :return [a href=/u/[?=c/@cid]/p/[?=c/@name]]]"
        ),
        "[a href=/u/42/p/Joe]"
    );
}

#[test]
fn fn_matches_regex() {
    assert_eq!(
        ev("[p s='hello42']", "[?=[?matches ['[a-z]+[0-9]+', @s]]]"),
        "true"
    );
}

#[test]
fn streaming_matches_buffered() {
    use std::sync::{Arc, Mutex};
    let doc = "[r [v n=1] [v n=2] [v n=3]]";
    let prog = "[?for x :in //v :return [?=x/@n]]";
    let buffered = ev(doc, prog);
    let chunks: Arc<Mutex<Vec<u8>>> = Arc::new(Mutex::new(Vec::new()));
    let chunks_cb = chunks.clone();
    cxlib::eval_cxl_streaming(doc, prog, "", move |b: &[u8]| {
        chunks_cb.lock().unwrap().extend_from_slice(b);
        Ok(())
    })
    .expect("streaming");
    let streamed = String::from_utf8(chunks.lock().unwrap().clone()).unwrap();
    assert_eq!(buffered, streamed);
}

// ── DD (cx: self-host module) cross-binding smoke tests ─────────────────

// DD3 cx:canonical wraps cx_text_canonical — idempotent
#[test]
fn cx_canonical_smoke() {
    let out = ev("[p]", "[?=[?cx:canonical [[?cx:parse ['[product name=A]']]]]]");
    assert!(out.contains("product"), "got: {:?}", out);
    assert!(out.contains("name=A"), "got: {:?}", out);
}

// DD4 cx:hash — SHA-256 hex, deterministic
#[test]
fn cx_hash_deterministic() {
    let prog = "[?=[?cx:hash [[?cx:parse ['[r x=1]']]]]]";
    let h1 = ev("[p]", prog);
    let h2 = ev("[p]", prog);
    assert_eq!(h1, h2);
    assert_eq!(h1.len(), 64, "expected 64-char hex digest, got {:?}", h1);
}

// DD7 cx:to-format json
#[test]
fn cx_to_format_json() {
    let out = ev("[p]", "[?=[?cx:to-format [[?cx:parse ['[u name=alice]']], 'json']]]");
    assert!(out.contains("alice"), "got: {:?}", out);
    assert!(out.contains('"'), "got: {:?}", out);
}

// DD9 cx:equal — identical equal; distinct differ
#[test]
fn cx_equal_identical() {
    assert_eq!(
        ev("[p]",
           "[?=[?cx:equal [[?cx:parse ['[r a=1]']], [?cx:parse ['[r a=1]']]]]]"),
        "true"
    );
}

#[test]
fn cx_equal_distinct() {
    assert_eq!(
        ev("[p]",
           "[?=[?cx:equal [[?cx:parse ['[a]']], [?cx:parse ['[b]']]]]]"),
        "false"
    );
}

// DD11 cx:eval — default off → CXER0041
#[test]
fn cx_eval_default_off_raises() {
    let res = cxlib::eval_cxl("[p]", "[?cx:eval ['[?=1]', {}]]", "");
    let err = res.expect_err("expected CXER0041 from cx:eval without allow-eval");
    let msg = format!("{}", err);
    assert!(msg.contains("CXER0041"), "got: {}", msg);
}

// DD11 cx:eval — engine runs once allow-eval set
#[test]
fn cx_eval_with_allow_eval() {
    let out = ev("[p]", "[?cx allow-eval=true][?cx:eval ['[?=1]', {}]]");
    assert!(out.contains('1'), "got: {:?}", out);
}

// DD12 cx:render — engine returns rendered text
#[test]
fn cx_render_with_allow_eval() {
    let out = ev("[p]", "[?cx allow-eval=true][?cx:render ['[?=42]', {}]]");
    assert!(out.contains("42"), "got: {:?}", out);
}

// ── FF (log: structured-logging) cross-binding smoke tests ──────────────

// FF3 log:info under [?cx pure-only] refused (EE4)
#[test]
fn log_info_under_pure_only_refused() {
    let res = cxlib::eval_cxl("[p]", "[?cx pure-only][?log:info ['hi', {}]]", "");
    let err = res.expect_err("expected CXER0040 — log: is SideEffect under pure-only");
    let msg = format!("{}", err);
    assert!(msg.contains("CXER0040"), "got: {}", msg);
}

// FF6 log:level — ReadOnly; returns current effective level
#[test]
fn log_level_returns_string() {
    assert_eq!(ev("[p]", "[?cx log-level=debug][?=[?log:level]]"), "debug");
}
