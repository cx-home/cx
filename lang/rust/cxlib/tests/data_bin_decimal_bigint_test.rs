//! I1 L48 — decimal / bigint parity for the NATIVE CXCol codec.
//!
//! The identity epoch promoted `decimal` and `bigint` to first-class
//! semantic kinds with their own data-bin wire tags (0x28 / 0x18; see
//! vcx/cx/data_bin.v). Both carry the same length-prefixed byte payload
//! the string tag (0x30) uses, holding the base-10 IMAGE:
//!   - decimal is FIXED-POINT base-10 only — scale (trailing zeros) is
//!     preserved ("1.10" stays "1.10"); exponent form is NOT a legal
//!     wire image;
//!   - bigint is a base-10 integer string, and an in-i64 bigint STILL
//!     rides 0x18 (narrowing-within-kind: the kind is never erased).
//!
//! Host mapping (spec/03-approved/misc/type-mapping.md, normative):
//! decimal = bigdecimal::BigDecimal, bigint = num_bigint::BigInt.
//!
//! Fixture-first: the decode tests run against hand-built framed
//! payloads, independent of the live library; the live tests then
//! cross-check against libcx's own encoder.

use bigdecimal::BigDecimal;
use num_bigint::BigInt;
use std::str::FromStr;

use cxlib::data_bin::{
    decode_payload, decode_payload_value, encode, encode_value, from_data_bin, to_data_bin,
    CxValue,
};

// ── hand-built payload helpers ───────────────────────────────────────────────

/// 12-byte CXCol v1 header (spec/core/data-bin.md §3.1) + value section.
fn cxcol_payload(value_bytes: &[u8]) -> Vec<u8> {
    let mut p = Vec::with_capacity(12 + value_bytes.len());
    p.extend_from_slice(b"CXCol");
    p.push(0x01); // version
    p.push(0x01); // flags: little-endian
    p.extend_from_slice(&64u32.to_le_bytes()); // max_depth
    p.push(0); // reserved
    p.extend_from_slice(value_bytes);
    p
}

/// Tag byte + uvarint length + base-10 image bytes — the shared
/// string-shaped payload the 0x18 / 0x28 kinds ride.
fn tagged_image(tag: u8, image: &str) -> Vec<u8> {
    assert!(image.len() < 0x80, "test images stay below one uvarint byte");
    let mut v = vec![tag, image.len() as u8];
    v.extend_from_slice(image.as_bytes());
    v
}

/// Pull the wire image back out of a FRAMED encode_value buffer,
/// asserting the expected kind tag.
fn wire_image(framed: &[u8], expect_tag: u8) -> String {
    let payload = &framed[4..]; // strip the [u32 LE size] frame
    assert_eq!(
        payload[12], expect_tag,
        "expected wire tag 0x{:02x}, got 0x{:02x}", expect_tag, payload[12]
    );
    let n = payload[13] as usize;
    assert!(n < 0x80, "single-byte uvarint expected in tests");
    String::from_utf8(payload[14..14 + n].to_vec()).expect("utf-8 image")
}

// ── host-mapping pin (task-mandated) ─────────────────────────────────────────

#[test]
fn bigdecimal_scale_preservation_pin() {
    // Normative pin: bigdecimal preserves the parsed scale — "1.10"
    // must NOT collapse to "1.1" (I1 L48 scale preservation).
    let d = BigDecimal::from_str("1.10").expect("parse 1.10");
    assert_eq!(d.to_string(), "1.10", "Display must keep the scale");
    assert_eq!(d.to_plain_string(), "1.10", "plain form must keep the scale");
}

// ── decode: hand-built framed payloads ───────────────────────────────────────

#[test]
fn decode_decimal_scale_preserved() {
    let payload = cxcol_payload(&tagged_image(0x28, "1.10"));
    let v = decode_payload_value(&payload).expect("decode 0x28");
    match v {
        CxValue::Decimal(d) => assert_eq!(d.to_plain_string(), "1.10"),
        other => panic!("expected CxValue::Decimal, got {other:?}"),
    }
}

#[test]
fn decode_bigint_beyond_i64() {
    let img = "99999999999999999999999"; // > i64::MAX
    let payload = cxcol_payload(&tagged_image(0x18, img));
    let v = decode_payload_value(&payload).expect("decode 0x18");
    match v {
        CxValue::BigInt(b) => assert_eq!(b.to_string(), img),
        other => panic!("expected CxValue::BigInt, got {other:?}"),
    }
}

#[test]
fn decode_bigint_in_i64_keeps_kind() {
    // Narrowing-within-kind: an in-i64 value on 0x18 is STILL a bigint
    // — the decoder must not erase the kind to Int.
    let payload = cxcol_payload(&tagged_image(0x18, "42"));
    let v = decode_payload_value(&payload).expect("decode 0x18 in-i64");
    match v {
        CxValue::BigInt(b) => assert_eq!(b, BigInt::from(42)),
        other => panic!("expected CxValue::BigInt (kind never erased), got {other:?}"),
    }
}

#[test]
fn decode_rejects_exponent_decimal_image() {
    // Exponent form is NOT a legal wire image for 0x28.
    let payload = cxcol_payload(&tagged_image(0x28, "1.1e2"));
    let err = decode_payload_value(&payload).unwrap_err();
    assert!(err.contains("fixed-point"), "got: {err}");
}

#[test]
fn decode_rejects_fractional_bigint_image() {
    let payload = cxcol_payload(&tagged_image(0x18, "1.5"));
    let err = decode_payload_value(&payload).unwrap_err();
    assert!(err.contains("base-10 integer"), "got: {err}");
}

#[test]
fn decode_unknown_tag_error_stays() {
    // Genuinely unknown tags still fail loudly as unknown.
    let payload = cxcol_payload(&[0x7F]);
    let err = decode_payload_value(&payload).unwrap_err();
    assert!(err.contains("unknown tag 0x7f"), "got: {err}");
    let err_json = decode_payload(&payload).unwrap_err();
    assert!(err_json.contains("unknown tag 0x7f"), "got: {err_json}");
}

#[test]
fn json_projection_fails_loud_not_erased() {
    // decode_payload (serde_json surface) has no carrier for either
    // kind — it must error and point at the typed API, never erase.
    let payload = cxcol_payload(&tagged_image(0x28, "1.10"));
    let err = decode_payload(&payload).unwrap_err();
    assert!(err.contains("decode_payload_value"), "got: {err}");

    let payload = cxcol_payload(&tagged_image(0x18, "42"));
    let err = decode_payload(&payload).unwrap_err();
    assert!(err.contains("decode_payload_value"), "got: {err}");
}

// ── encode: kind tags + round-trips ──────────────────────────────────────────

#[test]
fn encode_decimal_round_trips_with_scale() {
    let d = BigDecimal::from_str("1.10").unwrap();
    let framed = encode_value(&CxValue::Decimal(d)).expect("encode decimal");
    assert_eq!(wire_image(&framed, 0x28), "1.10", "scale preserved on the wire");
    match decode_payload_value(&framed[4..]).expect("re-decode") {
        CxValue::Decimal(back) => assert_eq!(back.to_plain_string(), "1.10"),
        other => panic!("expected CxValue::Decimal, got {other:?}"),
    }
}

#[test]
fn encode_bigint_always_rides_0x18() {
    // In-i64 bigint: kind is never erased to the int-tag family.
    let framed = encode_value(&CxValue::BigInt(BigInt::from(42))).unwrap();
    assert_eq!(wire_image(&framed, 0x18), "42");
    match decode_payload_value(&framed[4..]).unwrap() {
        CxValue::BigInt(b) => assert_eq!(b, BigInt::from(42)),
        other => panic!("expected CxValue::BigInt, got {other:?}"),
    }

    // Beyond i64.
    let big = BigInt::from_str("99999999999999999999999").unwrap();
    let framed = encode_value(&CxValue::BigInt(big.clone())).unwrap();
    assert_eq!(wire_image(&framed, 0x18), "99999999999999999999999");
    match decode_payload_value(&framed[4..]).unwrap() {
        CxValue::BigInt(b) => assert_eq!(b, big),
        other => panic!("expected CxValue::BigInt, got {other:?}"),
    }
}

#[test]
fn encode_plain_int_stays_on_int_tag_family() {
    // Plain i64 keeps the canonical int-tag narrowing — never 0x18.
    let framed = encode_value(&CxValue::Int(42)).unwrap();
    assert_eq!(framed[4 + 12], 0x10, "42 narrows to int8");
    let framed = encode_value(&CxValue::Int(5_000_000_000)).unwrap();
    assert_eq!(framed[4 + 12], 0x13, "beyond i32 rides int64 (0x13)");
}

#[test]
fn encoder_emits_fixed_point_never_exponent() {
    // BigDecimal happily parses exponent forms and its Display can
    // emit scientific notation at extreme scales; the WIRE image must
    // be fixed-point regardless.
    for (input, expect) in [
        ("1E-25", "0.0000000000000000000000001"),
        ("1e25", "10000000000000000000000000"),
        ("-2.5E-10", "-0.00000000025"),
    ] {
        let d = BigDecimal::from_str(input).unwrap();
        let framed = encode_value(&CxValue::Decimal(d)).unwrap();
        let img = wire_image(&framed, 0x28);
        assert!(
            !img.contains('e') && !img.contains('E'),
            "exponent leaked into wire image for {input}: {img}"
        );
        assert_eq!(img, expect, "fixed-point image for {input}");
        // And the strict decoder accepts its own output.
        decode_payload_value(&framed[4..]).expect("round-trip");
    }
}

#[test]
fn kinds_survive_nesting() {
    // decimal / bigint inside arrays and maps round-trip with their
    // kinds intact.
    let tree = CxValue::Map(vec![(
        "xs".to_owned(),
        CxValue::Array(vec![
            CxValue::Decimal(BigDecimal::from_str("0.500").unwrap()),
            CxValue::BigInt(BigInt::from_str("18446744073709551616").unwrap()),
            CxValue::Int(7),
        ]),
    )]);
    let framed = encode_value(&tree).unwrap();
    let back = decode_payload_value(&framed[4..]).unwrap();
    match &back {
        CxValue::Map(pairs) => match &pairs[0].1 {
            CxValue::Array(items) => {
                match &items[0] {
                    CxValue::Decimal(d) => assert_eq!(d.to_plain_string(), "0.500"),
                    other => panic!("expected Decimal, got {other:?}"),
                }
                match &items[1] {
                    CxValue::BigInt(b) => {
                        assert_eq!(b.to_string(), "18446744073709551616")
                    }
                    other => panic!("expected BigInt, got {other:?}"),
                }
                assert_eq!(items[2], CxValue::Int(7));
            }
            other => panic!("expected Array, got {other:?}"),
        },
        other => panic!("expected Map, got {other:?}"),
    }
}

#[test]
fn json_u64_beyond_i64_dumps_as_bigint_encoding() {
    // type-mapping §5: a native integer outside the i64 range dumps
    // with the bigint encoding (matches V's cx_to_data_bin, L20).
    let v = serde_json::json!(18_446_744_073_709_551_615u64);
    let framed = encode(&v).expect("encode u64 max");
    assert_eq!(wire_image(&framed, 0x18), "18446744073709551615");
}

// ── live cross-checks against libcx's own encoder ────────────────────────────

fn find_decimal(v: &CxValue) -> Option<&BigDecimal> {
    match v {
        CxValue::Decimal(d) => Some(d),
        CxValue::Array(items) => items.iter().find_map(find_decimal),
        CxValue::Map(pairs) => pairs.iter().find_map(|(_, v)| find_decimal(v)),
        _ => None,
    }
}

fn find_bigint(v: &CxValue) -> Option<&BigInt> {
    match v {
        CxValue::BigInt(b) => Some(b),
        CxValue::Array(items) => items.iter().find_map(find_bigint),
        CxValue::Map(pairs) => pairs.iter().find_map(|(_, v)| find_bigint(v)),
        _ => None,
    }
}

#[test]
fn live_decimal_round_trip_through_libcx() {
    // libcx encodes the bare decimal-point literal as the decimal kind
    // (I1): the native decoder must see 0x28 with the scale intact.
    let payload = to_data_bin("[price 1.10]").expect("cx_to_data_bin");
    let v = decode_payload_value(&payload).expect("native decode");
    let d = find_decimal(&v).expect("a decimal in the tree");
    assert_eq!(d.to_plain_string(), "1.10", "scale preserved end-to-end");

    // And libcx accepts the native encoder's bytes back.
    let framed = encode_value(&v).expect("native encode");
    let cx_text = from_data_bin(&framed).expect("cx_from_data_bin");
    assert!(cx_text.contains("1.10"), "got: {cx_text}");
}

#[test]
fn live_bigint_round_trip_through_libcx() {
    // An int literal beyond i64 auto-promotes to bigint (L20) — the
    // native decoder receives 0x18, never an overflow error.
    let img = "99999999999999999999999";
    let payload = to_data_bin(&format!("[n {img}]")).expect("cx_to_data_bin");
    let v = decode_payload_value(&payload).expect("native decode");
    let b = find_bigint(&v).expect("a bigint in the tree");
    assert_eq!(b.to_string(), img);

    let framed = encode_value(&v).expect("native encode");
    let cx_text = from_data_bin(&framed).expect("cx_from_data_bin");
    assert!(cx_text.contains(img), "got: {cx_text}");
}

// ── #807(c)/(d) (packet §10 arc-2): declared-name annotation +
// datetime-offset carriage, live through libcx's own encoder ─────────

#[test]
fn live_annotated_col_spec_and_offset_through_libcx() {
    // libcx annotates aliased col-specs (the 0x82 declared-name entry)
    // and carries datetime offset_minutes on the transport; the native
    // decoder consumes both.
    let payload = to_data_bin(
        "[t [table[v::f64 s::string w::datetime]]\n  1.5e0 x 2026-01-01T23:00:00+02:00\n]",
    )
    .expect("cx_to_data_bin");
    let v = decode_payload_value(&payload).expect("native decode");
    let mut strings = Vec::new();
    collect_strings(&v, &mut strings);
    assert!(
        strings.iter().any(|s| s == "2026-01-01T23:00:00+02:00"),
        "datetime offset must survive the wire; got {strings:?}"
    );
    assert!(
        strings.iter().any(|s| s == "x"),
        "annotated string column payload must stay intact; got {strings:?}"
    );
}

fn collect_strings(v: &CxValue, out: &mut Vec<String>) {
    match v {
        CxValue::String(s) => out.push(s.clone()),
        CxValue::Array(items) => items.iter().for_each(|i| collect_strings(i, out)),
        CxValue::Map(pairs) => pairs.iter().for_each(|(_, i)| collect_strings(i, out)),
        _ => {}
    }
}
