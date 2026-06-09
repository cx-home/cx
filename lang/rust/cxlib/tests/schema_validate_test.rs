//! Smoke test for the Rust schema-validator wrapper. Mirrors a few
//! fixtures from `conformance/schema_validate.txt`; the full conformance
//! sweep lives on the V/Python/Go side and exercises the same C ABI.

use cxlib::validate::{validate, validate_apply_defaults, Severity};

const BOOK_SCHEMA: &str = r#"
[?cx schema-of book]

[book
  [body :elem]
  [attr id :string :req]
  [elem title :card='1..1']
  [elem author :card='1..*']
]

[title [body :string]]
[author [body :string]]
"#;

#[test]
fn valid_book_no_diagnostics() {
    let doc = r#"
[book id='b1'
  [title 'The Stand']
  [author 'King']
]
"#;
    let report = validate(doc, BOOK_SCHEMA).expect("validate ok");
    assert!(report.is_valid(), "expected zero errors, got {:?}", report.error_codes());
    assert_eq!(report.error_count(), 0);
}

#[test]
fn missing_required_attr_fires_s002() {
    let doc = r#"
[book
  [title 'X']
  [author 'Y']
]
"#;
    let report = validate(doc, BOOK_SCHEMA).expect("validate ok");
    assert_eq!(report.error_codes(), vec!["S002".to_string()]);
    assert_eq!(report.diagnostics[0].severity, Severity::Error);
}

#[test]
fn root_mismatch_fires_s017() {
    let doc = "[other id='x']";
    let report = validate(doc, BOOK_SCHEMA).expect("validate ok");
    assert_eq!(report.error_codes(), vec!["S017".to_string()]);
}

#[test]
fn schema_directive_no_caller_schema_fires_s010() {
    // spec/schema.md §13 — directive present but validator has no
    // way to resolve the path (no caller-supplied schema source).
    let doc = r#"
[?cx schema=path/to/book.cxs]
[book id='b1'
  [title 'X']
]
"#;
    let report = validate(doc, "").expect("validate ok");
    assert_eq!(report.error_codes(), vec!["S010".to_string()]);
}

#[test]
fn apply_defaults_writes_modified_doc() {
    // Schema declares `:def='localhost'` for `host`; the doc omits it.
    // The defaults pass writes the populated form into modified_doc.
    // Sticking to a string-typed attribute here avoids the unrelated
    // i32-default-from-string coercion path (which is the
    // S011 territory tested by sv-039).
    let schema = r#"
[?cx schema-of server]

[server
  [attr host::string [default 'localhost']]
]
"#;
    let doc = "[server]";
    let report = validate_apply_defaults(doc, schema).expect("validate_apply_defaults ok");
    assert!(report.is_valid(), "unexpected errors: {:?}", report.error_codes());
    assert!(
        report.modified_doc.contains("host="),
        "expected modified_doc to carry the default; got {:?}", report.modified_doc,
    );
}
