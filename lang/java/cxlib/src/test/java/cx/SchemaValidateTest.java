package cx;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

/**
 * Smoke test for the Java schema-validator wrapper. Mirrors the
 * Rust binding's smoke set; the full 51-fixture conformance sweep
 * lives on the V/Python/Go side (same C ABI).
 */
public class SchemaValidateTest {

    private static final String BOOK_SCHEMA = """
            [?cx schema-of book]

            [book
              [body :elem]
              [attr id :string :req]
              [elem title :card='1..1']
              [elem author :card='1..*']
            ]

            [title [body :string]]
            [author [body :string]]
            """;

    @Test
    void validBookProducesNoDiagnostics() {
        String doc = """
                [book id='b1'
                  [title 'The Stand']
                  [author 'King']
                ]
                """;
        ValidationReport r = CxLib.validate(doc, BOOK_SCHEMA);
        assertTrue(r.isValid(), "expected zero errors, got " + r.errorCodes());
        assertEquals(0, r.errorCount());
    }

    @Test
    void missingRequiredAttrFiresS002() {
        String doc = """
                [book
                  [title 'X']
                  [author 'Y']
                ]
                """;
        ValidationReport r = CxLib.validate(doc, BOOK_SCHEMA);
        assertEquals(List.of("S002"), r.errorCodes());
        assertEquals(Severity.ERROR, r.diagnostics.get(0).severity());
    }

    @Test
    void rootMismatchFiresS017() {
        ValidationReport r = CxLib.validate("[other id='x']", BOOK_SCHEMA);
        assertEquals(List.of("S017"), r.errorCodes());
    }

    @Test
    void schemaDirectiveWithoutCallerSchemaFiresS010() {
        // spec/schema.md §13 — directive present but validator has no
        // way to resolve the path (no caller-supplied schema source).
        String doc = """
                [?cx schema=path/to/book.cxs]
                [book id='b1'
                  [title 'X']
                ]
                """;
        ValidationReport r = CxLib.validate(doc, "");
        assertEquals(List.of("S010"), r.errorCodes());
    }

    @Test
    void applyDefaultsWritesModifiedDoc() {
        String schema = """
                [?cx schema-of server]

                [server
                  [body :elem]
                  [attr host :string :def='localhost']
                ]
                """;
        ValidationReport r = CxLib.validateWithDefaults("[server]", schema);
        assertTrue(r.isValid(), "unexpected errors: " + r.errorCodes());
        assertTrue(r.modifiedDoc.contains("host="),
                "expected modifiedDoc to carry the default; got " + r.modifiedDoc);
    }
}
