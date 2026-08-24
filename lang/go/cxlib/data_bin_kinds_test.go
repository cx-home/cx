package cxlib

import (
	"bytes"
	"encoding/hex"
	"math/big"
	"testing"

	"github.com/cockroachdb/apd/v3"
)

// I1 L48 — decimal (0x28) and bigint (0x18) are first-class semantic
// kinds on the CXCol wire. Payload for both is the same length-prefixed
// byte payload the string tag (0x30) uses, carrying the base-10 IMAGE:
//   - decimal: FIXED-POINT base-10 only, scale / trailing zeros preserved
//     ("1.10" stays "1.10"); exponent form is NOT a legal wire image.
//   - bigint: base-10 integer string. Narrowing-within-kind — an in-i64
//     bigint STILL rides 0x18; the kind is never erased.
// Host mapping (spec/03-approved/misc/type-mapping.md): Go decimal is an
// exact decimal library, Go bigint is *big.Int. cockroachdb/apd/v3 is
// the exact-decimal pick: shopspring/decimal was tried first and FAILED
// the scale pin below (its String() trims trailing zeros, "1.10"->"1.1").

// kindsPayload hand-builds a CXCol v1 payload (12-byte header + one
// tagged length-prefixed image) for decoder tests. Images here are
// short (< 0x80 bytes), so the uvarint length is a single byte.
func kindsPayload(tag byte, image string) []byte {
	if len(image) >= 0x80 {
		panic("kindsPayload: image too long for single-byte uvarint")
	}
	p := []byte{'C', 'X', 'C', 'o', 'l', 0x01, 0x01, 64, 0, 0, 0, 0}
	p = append(p, tag, byte(len(image)))
	return append(p, image...)
}

// ── (a) decode: 0x28 decimal, scale preserved ────────────────────────────────

func TestDecodeDecimalPreservesScale(t *testing.T) {
	v, err := decodeDataBin(kindsPayload(tagDecimal, "1.10"))
	if err != nil {
		t.Fatalf("decodeDataBin(0x28 \"1.10\"): %v", err)
	}
	d, ok := v.(*apd.Decimal)
	if !ok {
		t.Fatalf("expected *apd.Decimal, got %T (%v)", v, v)
	}
	// Scale preservation pin: the trailing zero survives the round-trip.
	if got := d.Text('f'); got != "1.10" {
		t.Fatalf("scale not preserved: want %q, got %q", "1.10", got)
	}
}

// Pins the library-level guarantee the codec relies on, independent of
// the wire: apd preserves the parsed exponent through Text('f').
// (shopspring/decimal FAILS this pin — String() yields "1.1".)
func TestApdScalePreservationPinned(t *testing.T) {
	d, _, err := apd.NewFromString("1.10")
	if err != nil {
		t.Fatalf("NewFromString: %v", err)
	}
	if got := d.Text('f'); got != "1.10" {
		t.Fatalf("apd dropped scale: want %q, got %q", "1.10", got)
	}
}

func TestDecodeDecimalRejectsExponentImage(t *testing.T) {
	// Exponent form is not a legal wire image; the decoder fails loud.
	if _, err := decodeDataBin(kindsPayload(tagDecimal, "1e2")); err == nil {
		t.Fatal("expected error for exponent-form decimal image \"1e2\", got nil")
	}
	if _, err := decodeDataBin(kindsPayload(tagDecimal, "not-a-number")); err == nil {
		t.Fatal("expected error for malformed decimal image, got nil")
	}
	if _, err := decodeDataBin(kindsPayload(tagDecimal, "NaN")); err == nil {
		t.Fatal("expected error for non-finite decimal image, got nil")
	}
}

// ── (b) decode: 0x18 bigint — kind never erased ──────────────────────────────

func TestDecodeBigintBeyondI64(t *testing.T) {
	const image = "99999999999999999999999" // > i64 max
	v, err := decodeDataBin(kindsPayload(tagBigint, image))
	if err != nil {
		t.Fatalf("decodeDataBin(0x18 %q): %v", image, err)
	}
	n, ok := v.(*big.Int)
	if !ok {
		t.Fatalf("expected *big.Int, got %T (%v)", v, v)
	}
	want, _ := new(big.Int).SetString(image, 10)
	if n.Cmp(want) != 0 {
		t.Fatalf("bigint value mismatch: want %s, got %s", want, n)
	}
}

func TestDecodeBigintInI64KindNotErased(t *testing.T) {
	// Narrowing-within-kind: an in-i64 image on 0x18 still decodes to
	// *big.Int — never to int64.
	v, err := decodeDataBin(kindsPayload(tagBigint, "42"))
	if err != nil {
		t.Fatalf("decodeDataBin(0x18 \"42\"): %v", err)
	}
	n, ok := v.(*big.Int)
	if !ok {
		t.Fatalf("kind erased: expected *big.Int, got %T (%v)", v, v)
	}
	if n.Int64() != 42 {
		t.Fatalf("bigint value mismatch: want 42, got %s", n)
	}
}

func TestDecodeBigintRejectsBadImage(t *testing.T) {
	if _, err := decodeDataBin(kindsPayload(tagBigint, "12x4")); err == nil {
		t.Fatal("expected error for malformed bigint image, got nil")
	}
}

// ── (c) encode round-trips ───────────────────────────────────────────────────

func TestEncodeDecodeBigintRoundTrip(t *testing.T) {
	huge, _ := new(big.Int).SetString("99999999999999999999999", 10)
	for _, in := range []*big.Int{huge, big.NewInt(42)} {
		framed, err := encodeDataBin(in)
		if err != nil {
			t.Fatalf("encodeDataBin(%s): %v", in, err)
		}
		// Tag check: bigint rides 0x18 ALWAYS, even in-i64 (bytes 0..4
		// are the frame u32; 4..16 the header; 16 the value tag).
		if framed[16] != tagBigint {
			t.Fatalf("bigint %s encoded tag 0x%02x, want 0x18", in, framed[16])
		}
		out, err := decodeDataBin(framed[4:])
		if err != nil {
			t.Fatalf("decode round-trip(%s): %v", in, err)
		}
		n, ok := out.(*big.Int)
		if !ok {
			t.Fatalf("round-trip kind erased: expected *big.Int, got %T", out)
		}
		if n.Cmp(in) != 0 {
			t.Fatalf("round-trip value mismatch: want %s, got %s", in, n)
		}
	}
}

func TestEncodeDecodeDecimalRoundTripPreservesScale(t *testing.T) {
	in, _, err := apd.NewFromString("1.10")
	if err != nil {
		t.Fatalf("NewFromString: %v", err)
	}
	framed, err := encodeDataBin(in)
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	if framed[16] != tagDecimal {
		t.Fatalf("decimal encoded tag 0x%02x, want 0x28", framed[16])
	}
	out, err := decodeDataBin(framed[4:])
	if err != nil {
		t.Fatalf("decode round-trip: %v", err)
	}
	d, ok := out.(*apd.Decimal)
	if !ok {
		t.Fatalf("round-trip kind erased: expected *apd.Decimal, got %T", out)
	}
	if got := d.Text('f'); got != "1.10" {
		t.Fatalf("round-trip scale lost: want %q, got %q", "1.10", got)
	}
}

func TestEncodePlainInt64StaysIntLattice(t *testing.T) {
	// A plain Go int64 stays on the int lattice (canonical narrowest
	// tag — 0x10 for 42), never 0x18.
	framed, err := encodeDataBin(int64(42))
	if err != nil {
		t.Fatalf("encodeDataBin(int64): %v", err)
	}
	if framed[16] == tagBigint {
		t.Fatal("plain int64 must not encode as bigint 0x18")
	}
	if framed[16] != tagInt8 {
		t.Fatalf("int64(42) canonical tag: want 0x10, got 0x%02x", framed[16])
	}
}

func TestEncodeNonFiniteDecimalErrors(t *testing.T) {
	var nan apd.Decimal
	nan.Form = apd.NaN
	if _, err := encodeDataBin(&nan); err == nil {
		t.Fatal("expected error encoding NaN decimal (no wire image), got nil")
	}
}

// ── (d) encoder emits fixed-point, never exponent ────────────────────────────

func TestEncodeDecimalFixedPointNeverExponent(t *testing.T) {
	// A decimal parsed from exponent input still hits the wire as a
	// fixed-point image ("1e2" -> "100").
	in, _, err := apd.NewFromString("1e2")
	if err != nil {
		t.Fatalf("NewFromString: %v", err)
	}
	framed, err := encodeDataBin(in)
	if err != nil {
		t.Fatalf("encodeDataBin: %v", err)
	}
	if framed[16] != tagDecimal {
		t.Fatalf("decimal encoded tag 0x%02x, want 0x28", framed[16])
	}
	payload := framed[17:] // uvarint len + image
	if bytes.ContainsAny(payload, "eE") {
		t.Fatalf("encoder emitted exponent-form image: %q", payload)
	}
	imageLen := int(payload[0])
	if got := string(payload[1 : 1+imageLen]); got != "100" {
		t.Fatalf("fixed-point image: want %q, got %q", "100", got)
	}
}

// ── libcx round-trip: Dumps -> canonical CX -> Loads keeps the kinds ─────────

func TestDumpsLoadsBigintDecimalKindsSurvive(t *testing.T) {
	huge, _ := new(big.Int).SetString("99999999999999999999999", 10)
	price, _, err := apd.NewFromString("1.10")
	if err != nil {
		t.Fatalf("NewFromString: %v", err)
	}
	src, err := Dumps(map[string]any{"n": huge, "p": price})
	if err != nil {
		t.Fatalf("Dumps: %v", err)
	}
	restored, err := Loads(src)
	if err != nil {
		t.Fatalf("Loads(%q): %v", src, err)
	}
	m, ok := restored.(map[string]any)
	if !ok {
		t.Fatalf("expected map, got %T (%v)", restored, restored)
	}
	n, ok := m["n"].(*big.Int)
	if !ok {
		t.Fatalf("bigint kind lost through canonical CX: got %T (%v); src=%q", m["n"], m["n"], src)
	}
	if n.Cmp(huge) != 0 {
		t.Fatalf("bigint value mismatch: want %s, got %s", huge, n)
	}
	d, ok := m["p"].(*apd.Decimal)
	if !ok {
		t.Fatalf("decimal kind lost through canonical CX: got %T (%v); src=%q", m["p"], m["p"], src)
	}
	if got := d.Text('f'); got != "1.10" {
		t.Fatalf("decimal scale lost through canonical CX: want %q, got %q (src=%q)", "1.10", got, src)
	}
}

// ── #807(c)/(d) (packet §10 arc-2): the 0x82 declared-name col-spec
// annotation + the datetime-offset transport carriage. Vectors are
// V-emitted (cx --cxcol) bare payloads.

func TestDecodeColSpecDeclaredNameAnnotation(t *testing.T) {
	// [t [table[v::f64 s::string]] 1.5e0 x] — both col-specs carry the
	// 0x82 annotation; the decoder consumes the declared spelling and
	// reads payloads from the real codes.
	payload, err := hex.DecodeString("4358436f6c010140000000005001300174600230017682300366363420300173823006737472696e673001000000000000f83f0178")
	if err != nil {
		t.Fatalf("hex: %v", err)
	}
	v, err := decodeDataBin(payload)
	if err != nil {
		t.Fatalf("decodeDataBin(annotated col-spec): %v", err)
	}
	row := v.(map[string]any)["t"].([]any)[0].(map[string]any)
	if got := row["v"].(float64); got != 1.5 {
		t.Fatalf("annotated f64 column: want 1.5, got %v", got)
	}
	if got := row["s"].(string); got != "x" {
		t.Fatalf("annotated string column: want \"x\", got %q", got)
	}
}

func TestDecodeDatetimeOffsetRidesTransport(t *testing.T) {
	// [t [table[w::datetime]] '2026-01-01T23:00:00+02:00'] — the
	// §3.6.1 offset_minutes field rides the transport; the local
	// render survives decode.
	payload, err := hex.DecodeString("4358436f6c0101400000000050013001746001300177320100201fed13b7861878000000")
	if err != nil {
		t.Fatalf("hex: %v", err)
	}
	v, err := decodeDataBin(payload)
	if err != nil {
		t.Fatalf("decodeDataBin(offset datetime): %v", err)
	}
	row := v.(map[string]any)["t"].([]any)[0].(map[string]any)
	if got := row["w"].(string); got != "2026-01-01T23:00:00+02:00" {
		t.Fatalf("datetime offset render: want the +02:00 local form, got %q", got)
	}
}
