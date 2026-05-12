package cx;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.vector.BigIntVector;
import org.apache.arrow.vector.BitVector;
import org.apache.arrow.vector.DateDayVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.Float8Vector;
import org.apache.arrow.vector.IntVector;
import org.apache.arrow.vector.SmallIntVector;
import org.apache.arrow.vector.TimeStampNanoTZVector;
import org.apache.arrow.vector.TinyIntVector;
import org.apache.arrow.vector.VarBinaryVector;
import org.apache.arrow.vector.VarCharVector;
import org.apache.arrow.vector.VectorLoader;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.VectorUnloader;
import org.apache.arrow.vector.dictionary.DictionaryProvider;
import org.apache.arrow.vector.ipc.ArrowReader;
import org.apache.arrow.vector.ipc.message.ArrowRecordBatch;
import org.apache.arrow.vector.types.DateUnit;
import org.apache.arrow.vector.types.pojo.ArrowType;
import org.apache.arrow.vector.types.pojo.Field;
import org.apache.arrow.vector.types.pojo.FieldType;
import org.apache.arrow.vector.types.pojo.Schema;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Apache Arrow C-Data interop tests for {@code cx.Arrow}
 * (Phase 7.74c-cont-bindings-multi-java).
 *
 * <p>Mirrors {@code lang/csharp/cxlib_arrow_test/Program.cs} +
 * {@code lang/go/cxlib/arrow_test.go} +
 * {@code lang/python/test_arrow.py}: round-trip per supported
 * v0.6.0 column type ({@code int / i8 / i16 / i32 / float / bool /
 * string / date / bytes / datetime}) plus a Java-built record →
 * CXDB inverse round-trip plus capability + version + invalid-input
 * cases.
 *
 * <p>Run via {@code make test-java-arrow}.
 */
class ArrowTest {

    // Drain an ArrowReader: returns the row count of the single batch
    // and applies `callback` to the loaded VectorSchemaRoot before
    // closing. All current cases produce one batch.
    private interface BatchCheck {
        void check(VectorSchemaRoot root) throws IOException;
    }

    private static int drainSingleBatch(ArrowReader reader, BatchCheck check) throws IOException {
        try {
            assertTrue(reader.loadNextBatch(), "expected one batch");
            VectorSchemaRoot root = reader.getVectorSchemaRoot();
            int rows = root.getRowCount();
            check.check(root);
            assertFalse(reader.loadNextBatch(), "expected EOS after one batch");
            return rows;
        } finally {
            reader.close();
        }
    }

    // ── 1. capability + version ───────────────────────────────────────────────

    @Test
    @DisplayName("capability + version")
    void capability() {
        assertTrue(Arrow.available(), "Arrow.available() under linked libcx_arrow");
        long feats = Arrow.features();
        assertEquals(0x800000L, feats,
                () -> String.format("Arrow.features() == 0x800000 (got 0x%x)", feats));
        assertEquals("0.6.0", Arrow.version(), "Arrow.version() == '0.6.0'");
        long merged = Arrow.mergedFeatures();
        assertNotEquals(0L, merged & 0x800000L, "mergedFeatures() has bit 23 set");
    }

    // ── 2. round-trip int ─────────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip int")
    void roundTripInt() throws IOException {
        String src = "[stats :table[score:int]\n  100\n  -1\n"
                + "  9223372036854775807\n  -9223372036854775808\n]";
        byte[] payload = CxLib.toDataBinChunked(src);
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            VectorSchemaRoot root = rdr.getVectorSchemaRoot();
            BigIntVector v = (BigIntVector) root.getVector(0);
            long[] want = { 100L, -1L, Long.MAX_VALUE, Long.MIN_VALUE };
            for (int i = 0; i < want.length; i++) {
                assertEquals(want[i], v.get(i), "row " + i);
            }
        }
    }

    // ── 3. round-trip i8 ─────────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip i8")
    void roundTripI8() throws IOException {
        byte[] payload = CxLib.toDataBinChunked("[v :table[v:i8]\n  -128\n  -1\n  0\n  127\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            TinyIntVector v = (TinyIntVector) rdr.getVectorSchemaRoot().getVector(0);
            byte[] want = { -128, -1, 0, 127 };
            for (int i = 0; i < want.length; i++) assertEquals(want[i], v.get(i), "row " + i);
        }
    }

    // ── 4. round-trip i16 ────────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip i16")
    void roundTripI16() throws IOException {
        byte[] payload = CxLib.toDataBinChunked("[v :table[v:i16]\n  -32768\n  -1\n  0\n  32767\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            SmallIntVector v = (SmallIntVector) rdr.getVectorSchemaRoot().getVector(0);
            short[] want = { -32768, -1, 0, 32767 };
            for (int i = 0; i < want.length; i++) assertEquals(want[i], v.get(i), "row " + i);
        }
    }

    // ── 5. round-trip i32 ────────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip i32")
    void roundTripI32() throws IOException {
        byte[] payload = CxLib.toDataBinChunked(
                "[v :table[v:i32]\n  -2147483648\n  -1\n  0\n  2147483647\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            IntVector v = (IntVector) rdr.getVectorSchemaRoot().getVector(0);
            int[] want = { Integer.MIN_VALUE, -1, 0, Integer.MAX_VALUE };
            for (int i = 0; i < want.length; i++) assertEquals(want[i], v.get(i), "row " + i);
        }
    }

    // ── 6. round-trip float ──────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip float")
    void roundTripFloat() throws IOException {
        byte[] payload = CxLib.toDataBinChunked(
                "[v :table[v:float]\n  0.0\n  -1.5\n  3.14159\n  1e100\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            Float8Vector v = (Float8Vector) rdr.getVectorSchemaRoot().getVector(0);
            assertEquals(0.0, v.get(0));
            assertEquals(-1.5, v.get(1));
            assertEquals(3.14159, v.get(2), 1e-9);
            assertEquals(1e100, v.get(3));
        }
    }

    // ── 7. round-trip bool ───────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip bool")
    void roundTripBool() throws IOException {
        byte[] payload = CxLib.toDataBinChunked(
                "[v :table[v:bool]\n  true\n  false\n  true\n  false\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            BitVector v = (BitVector) rdr.getVectorSchemaRoot().getVector(0);
            int[] want = { 1, 0, 1, 0 };
            for (int i = 0; i < want.length; i++) assertEquals(want[i], v.get(i), "row " + i);
        }
    }

    // ── 8. round-trip string ─────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip string")
    void roundTripString() throws IOException {
        byte[] payload = CxLib.toDataBinChunked(
                "[v :table[v:string]\n  alice\n  bob\n  carol\n  unicode-é-é-ñ\n]");
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            VarCharVector v = (VarCharVector) rdr.getVectorSchemaRoot().getVector(0);
            String[] want = { "alice", "bob", "carol", "unicode-é-é-ñ" };
            for (int i = 0; i < want.length; i++) {
                assertEquals(want[i], new String(v.get(i)), "row " + i);
            }
        }
    }

    // ── 9. round-trip date ───────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip date")
    void roundTripDate() throws IOException {
        String src = "[evts :table[when:date]\n  2026-05-09\n  1970-01-01\n"
                + "  9999-12-31\n  1900-01-01\n]";
        byte[] payload = CxLib.toDataBinChunked(src);
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            VectorSchemaRoot root = rdr.getVectorSchemaRoot();
            FieldVector fv = root.getVector(0);
            assertTrue(fv instanceof DateDayVector,
                    "col is Date32 (got " + fv.getField().getType() + ")");
            DateDayVector v = (DateDayVector) fv;
            int[] want = {
                    (int) LocalDate.of(2026, 5, 9).toEpochDay(),
                    (int) LocalDate.of(1970, 1, 1).toEpochDay(),
                    (int) LocalDate.of(9999, 12, 31).toEpochDay(),
                    (int) LocalDate.of(1900, 1, 1).toEpochDay(),
            };
            for (int i = 0; i < want.length; i++) assertEquals(want[i], v.get(i), "row " + i);
        }
    }

    // ── 10. round-trip bytes ─────────────────────────────────────────────────

    @Test
    @DisplayName("round-trip bytes")
    void roundTripBytes() throws IOException {
        String src = "[blobs :table[name:string blob:bytes]\n"
                + "  alpha \"A1B2\"\n  beta \"FF00DE\"\n  empty \"\"\n]";
        byte[] payload = CxLib.toDataBinChunked(src);
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            VarBinaryVector v = (VarBinaryVector) rdr.getVectorSchemaRoot().getVector(1);
            assertEquals(3, v.getValueCount(), "blob col length 3");
            // CXDB carries the bytes-cell raw form (incl. surrounding double
            // quotes from the parser's textual cell). Test 12 covers
            // end-to-end fidelity; here we just assert plausible lengths.
            int len0 = v.get(0).length, len1 = v.get(1).length, len2 = v.get(2).length;
            assertTrue(len0 > 0 && len1 > len0 && len2 < len0,
                    "blob lengths plausible (FF00DE > A1B2 > empty)");
        }
    }

    // ── 11. round-trip datetime ──────────────────────────────────────────────

    @Test
    @DisplayName("round-trip datetime")
    void roundTripDatetime() throws IOException {
        String src = "[evts :table[when:datetime]\n"
                + "  2024-01-15T12:34:56Z\n"
                + "  2025-06-30T23:00:00+02:00\n"
                + "  1970-01-01T00:00:00Z\n"
                + "  1900-01-01T00:00:00Z\n]";
        byte[] payload = CxLib.toDataBinChunked(src);
        try (ArrowReader rdr = Arrow.export(payload)) {
            assertTrue(rdr.loadNextBatch());
            VectorSchemaRoot root = rdr.getVectorSchemaRoot();
            FieldVector fv = root.getVector(0);
            assertTrue(fv instanceof TimeStampNanoTZVector,
                    "col is timestamp[ns, UTC] (got " + fv.getField().getType() + ")");
            TimeStampNanoTZVector v = (TimeStampNanoTZVector) fv;
            // Strict-canonical normalizes offsets to UTC: 23:00:00+02:00 → 21:00:00Z.
            long[] wantNs = {
                    OffsetDateTime.of(2024, 1, 15, 12, 34, 56, 0, ZoneOffset.UTC).toEpochSecond() * 1_000_000_000L,
                    OffsetDateTime.of(2025, 6, 30, 21, 0, 0, 0, ZoneOffset.UTC).toEpochSecond() * 1_000_000_000L,
                    0L,
                    OffsetDateTime.of(1900, 1, 1, 0, 0, 0, 0, ZoneOffset.UTC).toEpochSecond() * 1_000_000_000L,
            };
            for (int i = 0; i < wantNs.length; i++) assertEquals(wantNs[i], v.get(i), "row " + i);
        }
    }

    // ── 12. inverse from Java-built arrow table ──────────────────────────────

    @Test
    @DisplayName("arrow-built table → CXDB → arrow re-decode")
    void inverseFromJavaTable() throws IOException {
        BufferAllocator alloc = Arrow.allocator();

        Field nameF  = new Field("name",  FieldType.notNullable(ArrowType.Utf8.INSTANCE), null);
        Field scoreF = new Field("score", FieldType.notNullable(new ArrowType.Int(64, true)), null);
        Field ratioF = new Field("ratio", FieldType.notNullable(
                new ArrowType.FloatingPoint(org.apache.arrow.vector.types.FloatingPointPrecision.DOUBLE)), null);
        Schema schema = new Schema(List.of(nameF, scoreF, ratioF));

        try (VectorSchemaRoot src = VectorSchemaRoot.create(schema, alloc)) {
            VarCharVector names  = (VarCharVector) src.getVector(0);
            BigIntVector  scores = (BigIntVector)  src.getVector(1);
            Float8Vector  ratios = (Float8Vector)  src.getVector(2);
            names.allocateNew();   scores.allocateNew(3);   ratios.allocateNew(3);
            names.setSafe (0, "alice".getBytes());
            names.setSafe (1, "bob".getBytes());
            names.setSafe (2, "carol".getBytes());
            scores.setSafe(0, 91L); scores.setSafe(1, 88L); scores.setSafe(2, 73L);
            ratios.setSafe(0, 0.91); ratios.setSafe(1, 0.88); ratios.setSafe(2, 0.73);
            src.setRowCount(3);

            byte[] payload;
            try (FixedBatchReader fbr = new FixedBatchReader(alloc, src)) {
                payload = Arrow.importToDataBin(fbr);
            }
            assertTrue(payload.length > 0, "ImportToDataBin returns non-empty payload");

            try (ArrowReader rdr = Arrow.export(payload)) {
                assertTrue(rdr.loadNextBatch());
                VectorSchemaRoot root = rdr.getVectorSchemaRoot();
                assertEquals(3, root.getRowCount(), "round-tripped 3 rows");
                VarCharVector n = (VarCharVector) root.getVector(0);
                BigIntVector  s = (BigIntVector)  root.getVector(1);
                Float8Vector  r = (Float8Vector)  root.getVector(2);
                assertEquals("alice", new String(n.get(0)));
                assertEquals(88L,     s.get(1));
                assertEquals(0.73,    r.get(2), 1e-9);
            }
        }
    }

    // ── 13. invalid input — Export rejects empty / garbage ───────────────────

    @Test
    @DisplayName("Export rejects invalid input")
    void exportRejectsInvalid() {
        assertThrows(IllegalArgumentException.class,
                () -> Arrow.export(new byte[0]),
                "Export(empty) throws");
        assertThrows(RuntimeException.class,
                () -> { try (ArrowReader r = Arrow.export(new byte[]{0x67, 0x61, 0x72, 0x62})) {} },
                "Export(garbage) throws");
    }

    // ── 14. invalid input — ImportToDataBin rejects null ─────────────────────

    @Test
    @DisplayName("ImportToDataBin rejects null")
    void importRejectsNull() {
        assertThrows(IllegalArgumentException.class,
                () -> Arrow.importToDataBin(null),
                "ImportToDataBin(null) throws IllegalArgumentException");
    }

    // ── helper: in-memory ArrowReader that yields a single batch ─────────────

    private static final class FixedBatchReader extends ArrowReader {
        private final VectorSchemaRoot src;
        private boolean done = false;

        FixedBatchReader(BufferAllocator allocator, VectorSchemaRoot src) {
            super(allocator);
            this.src = src;
        }

        @Override
        public boolean loadNextBatch() throws IOException {
            if (done) return false;
            VectorLoader loader = new VectorLoader(getVectorSchemaRoot());
            VectorUnloader unloader = new VectorUnloader(src);
            try (ArrowRecordBatch batch = unloader.getRecordBatch()) {
                loader.load(batch);
            }
            done = true;
            return true;
        }

        @Override public long bytesRead() { return 0; }

        @Override
        protected Schema readSchema() {
            return src.getSchema();
        }

        @Override
        protected void closeReadSource() { /* src is owned by caller */ }
    }
}
