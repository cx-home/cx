/*
 * c_abi_test.c — C-level ABI conformance test for libcx + libcx_arrow.
 *
 * Phase 7.74c-abi-c-test (per spec/abi.md §1.5, §2.10, §2.11). Compiled
 * with -fsanitize=address,undefined and run via `make abi-c-test`. The
 * boundary surface exercised here is where binding-runtime bugs have
 * actually surfaced (size-header garbage, double-free on Export error,
 * NULL-input rejection, framed-vs-unframed shape, missing release on
 * Arrow stream). Catching these at the C level removes the need to
 * roll a feature out across all 11 bindings just to gap-find ABI
 * issues.
 *
 * Surface (≈12 symbols):
 *   libcx (statically linked at compile time):
 *     cx_to_data_bin_chunked, cx_table_reader_open,
 *     cx_table_reader_schema, cx_table_reader_next, cx_table_reader_close,
 *     cx_table_writer_open, cx_table_writer_emit_row_group,
 *     cx_table_writer_close_get_bytes, cx_table_writer_close, cx_free
 *   libcx_arrow (dlopen at runtime — mirrors how bindings load it):
 *     cx_arrow_features, cx_arrow_version, cx_arrow_export_open,
 *     cx_arrow_import_to_data_bin, cx_arrow_free
 *
 * Usage: ./c_abi_test <path-to-libcx_arrow.dylib-or-.so>
 */

#include <assert.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cx.h"
#include "arrow_c_abi.h"

/* ── Test scaffolding ─────────────────────────────────────────────────── */

static int g_failed = 0;

#define FAIL(...) do { \
    fprintf(stderr, "FAIL %s:%d: ", __func__, __LINE__); \
    fprintf(stderr, __VA_ARGS__); \
    fputc('\n', stderr); \
    g_failed = 1; \
    return; \
} while (0)

#define PASS(name) printf("ok   %s\n", name)

/* Read the [u32 LE size] header of a framed CXCol buffer. */
static uint32_t framed_size(const char *buf) {
    const unsigned char *p = (const unsigned char *)buf;
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

/* Sample CX text borrowed from conformance/data_bin_arrow.txt
 * (arrow-002-float64-roundtrip). Two columns, two rows — enough to
 * round-trip through chunked emit, table reader/writer, and Arrow. */
static const char SAMPLE_TABLE[] =
    "[ratios [table[name::string ratio::float]]\n"
    "  alice 0.91\n"
    "  bob   0.88\n"
    "]\n";

/* ── libcx_arrow dlopen surface ───────────────────────────────────────── */

typedef char *(*fn_arrow_features_t)(void);
typedef char *(*fn_arrow_version_t)(void);
typedef char *(*fn_arrow_export_open_t)(const char *, void *, char **);
typedef char *(*fn_arrow_import_t)(void *, char **);
typedef void  (*fn_arrow_free_t)(char *);

static void *g_arrow_lib = NULL;
static fn_arrow_features_t   p_arrow_features = NULL;
static fn_arrow_version_t    p_arrow_version  = NULL;
static fn_arrow_export_open_t p_arrow_export  = NULL;
static fn_arrow_import_t     p_arrow_import   = NULL;
static fn_arrow_free_t       p_arrow_free     = NULL;

static int load_libcx_arrow(const char *path) {
    g_arrow_lib = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (!g_arrow_lib) {
        fprintf(stderr, "FAIL load_libcx_arrow: dlopen(%s): %s\n",
                path, dlerror());
        return 1;
    }
#define LOAD(LOCAL, SYMNAME, TY) do { \
        LOCAL = (TY)dlsym(g_arrow_lib, SYMNAME); \
        if (!LOCAL) { \
            fprintf(stderr, "FAIL load_libcx_arrow: dlsym %s: %s\n", \
                    SYMNAME, dlerror()); \
            return 1; \
        } \
    } while (0)
    LOAD(p_arrow_features, "cx_arrow_features",          fn_arrow_features_t);
    LOAD(p_arrow_version,  "cx_arrow_version",           fn_arrow_version_t);
    LOAD(p_arrow_export,   "cx_arrow_export_open",       fn_arrow_export_open_t);
    LOAD(p_arrow_import,   "cx_arrow_import_to_data_bin",fn_arrow_import_t);
    LOAD(p_arrow_free,     "cx_arrow_free",              fn_arrow_free_t);
#undef LOAD
    return 0;
}

/* ── Tests: libcx core (chunked + table reader/writer) ────────────────── */

static char *make_chunked_buffer(void) {
    char *err = NULL;
    char *buf = cx_to_data_bin_chunked(SAMPLE_TABLE, &err);
    if (!buf) {
        fprintf(stderr, "make_chunked_buffer: cx_to_data_bin_chunked: %s\n",
                err ? err : "(null)");
        cx_free(err);
        return NULL;
    }
    return buf;
}

static void test_chunked_happy_path(void) {
    char *err = NULL;
    char *buf = cx_to_data_bin_chunked(SAMPLE_TABLE, &err);
    if (!buf) {
        FAIL("cx_to_data_bin_chunked returned NULL: %s", err ? err : "(null)");
    }
    if (err) {
        FAIL("cx_to_data_bin_chunked set err on success: %s", err);
    }
    uint32_t sz = framed_size(buf);
    if (sz < 8) {
        FAIL("framed CXCol size implausibly small: %u", sz);
    }
    cx_free(buf);
    PASS("test_chunked_happy_path");
}

static void test_chunked_error_path(void) {
    /* Non-:table input must produce a clean error, not a NULL-deref. */
    char *err = NULL;
    char *buf = cx_to_data_bin_chunked("[not_a_table x 1]", &err);
    if (buf) {
        FAIL("cx_to_data_bin_chunked returned non-NULL on bad input");
    }
    if (!err) {
        FAIL("cx_to_data_bin_chunked failed without setting err_out");
    }
    cx_free(err);
    PASS("test_chunked_error_path");
}

static void test_table_reader_open_and_close(void) {
    char *buf = make_chunked_buffer();
    if (!buf) FAIL("setup");
    char *err = NULL;
    cx_table_reader_handle r = cx_table_reader_open(buf, &err);
    if (!r) {
        FAIL("cx_table_reader_open returned NULL: %s", err ? err : "(null)");
    }
    if (err) {
        FAIL("cx_table_reader_open set err on success: %s", err);
    }
    /* schema is framed ast_bin — non-NULL, well-framed. */
    char *schema = cx_table_reader_schema(r, &err);
    if (!schema) {
        FAIL("cx_table_reader_schema returned NULL: %s", err ? err : "(null)");
    }
    if (framed_size(schema) < 1) {
        FAIL("schema ast_bin size implausibly small");
    }
    /* Iterate row groups; SAMPLE_TABLE is small, expect at least one. */
    int n_groups = 0;
    for (;;) {
        char *rg = cx_table_reader_next(r, &err);
        if (!rg) {
            if (err) FAIL("cx_table_reader_next failed: %s", err);
            break;
        }
        n_groups++;
        cx_free(rg);
    }
    if (n_groups < 1) {
        FAIL("expected ≥1 row group, got 0");
    }
    cx_free(schema);
    cx_table_reader_close(r);
    cx_free(buf);
    PASS("test_table_reader_open_and_close");
}

static void test_table_reader_bad_input(void) {
    /* The C ABI has an implicit-length convention: the first 4 bytes
     * are read as a [u32 LE size] header, and `size` more bytes are
     * memcpy'd from the input. There is no length parameter, so a
     * truly garbage input that lies about its size will read out of
     * bounds (a finding bindings compensate for with their own
     * frame-validator on the caller side — see MIGRATION.md
     * Phase 7.74c-cont-bindings-multi-kotlin). This test instead
     * exercises the well-framed-but-bad-payload path: size header
     * claims 4 payload bytes (all zero), which is not a valid CXCol
     * chunked-table header. The function must reject without crashing. */
    static const char tiny_invalid[] = {
        0x04, 0x00, 0x00, 0x00,  /* size = 4 */
        0x00, 0x00, 0x00, 0x00,  /* invalid CXCol payload */
    };
    char *err = NULL;
    cx_table_reader_handle r = cx_table_reader_open(tiny_invalid, &err);
    if (r) {
        FAIL("cx_table_reader_open returned non-NULL on bad payload");
    }
    if (!err) {
        FAIL("cx_table_reader_open failed without setting err_out");
    }
    cx_free(err);
    PASS("test_table_reader_bad_input");
}

static void test_table_reader_writer_round_trip(void) {
    char *buf = make_chunked_buffer();
    if (!buf) FAIL("setup");
    char *err = NULL;
    cx_table_reader_handle r = cx_table_reader_open(buf, &err);
    if (!r) FAIL("reader open: %s", err ? err : "(null)");
    char *schema = cx_table_reader_schema(r, &err);
    if (!schema) FAIL("reader schema: %s", err ? err : "(null)");

    cx_table_writer_handle w = cx_table_writer_open(schema, &err);
    if (!w) FAIL("writer open: %s", err ? err : "(null)");
    if (err) FAIL("writer open set err on success: %s", err);

    int forwarded = 0;
    for (;;) {
        char *rg = cx_table_reader_next(r, &err);
        if (!rg) {
            if (err) FAIL("reader next: %s", err);
            break;
        }
        char *emit_err = cx_table_writer_emit_row_group(w, rg, &err);
        (void)emit_err;
        if (err) FAIL("writer emit: %s", err);
        forwarded++;
        cx_free(rg);
    }

    char *out = cx_table_writer_close_get_bytes(w, &err);
    if (!out) FAIL("writer close_get_bytes: %s", err ? err : "(null)");
    if (err) FAIL("writer close_get_bytes set err on success: %s", err);
    if (framed_size(out) < 8) {
        FAIL("writer output size implausibly small: %u", framed_size(out));
    }
    if (forwarded < 1) FAIL("forwarded zero row groups");

    cx_free(out);
    cx_free(schema);
    cx_table_reader_close(r);
    /* writer was already drained by close_get_bytes — that path frees
     * the handle. Calling cx_table_writer_close on it again would be
     * use-after-free; the API contract is one OR the other, not both. */
    cx_free(buf);
    PASS("test_table_reader_writer_round_trip");
}

static void test_null_safe_close(void) {
    /* Per spec/abi.md §2.10: both close functions accept NULL. */
    cx_table_reader_close(NULL);
    cx_table_writer_close(NULL);
    PASS("test_null_safe_close");
}

/* ── Tests: libcx_arrow (via dlopen) ──────────────────────────────────── */

static void test_arrow_capability_and_version(void) {
    char *feat = p_arrow_features();
    if (!feat) FAIL("cx_arrow_features returned NULL");
    if (strcmp(feat, "0x800000") != 0) {
        FAIL("cx_arrow_features: expected '0x800000', got '%s'", feat);
    }
    p_arrow_free(feat);

    char *ver = p_arrow_version();
    if (!ver) FAIL("cx_arrow_version returned NULL");
    /* Don't pin to exact version — just sanity-check non-empty. */
    if (ver[0] == '\0') FAIL("cx_arrow_version returned empty string");
    p_arrow_free(ver);
    PASS("test_arrow_capability_and_version");
}

static void test_arrow_round_trip(void) {
    char *buf = make_chunked_buffer();
    if (!buf) FAIL("setup");

    struct ArrowArrayStream stream;
    memset(&stream, 0, sizeof(stream));
    char *err = NULL;
    char *rc = p_arrow_export(buf, &stream, &err);
    /* cx_arrow_export_open returns NULL on success; err remains NULL. */
    if (rc) FAIL("cx_arrow_export_open returned non-NULL");
    if (err) FAIL("cx_arrow_export_open set err on success: %s", err);
    if (!stream.release) FAIL("export did not populate stream.release");
    if (!stream.get_schema) FAIL("export did not populate stream.get_schema");

    char *out = p_arrow_import(&stream, &err);
    if (!out) FAIL("cx_arrow_import_to_data_bin returned NULL: %s",
                   err ? err : "(null)");
    if (err) FAIL("import set err on success: %s", err);
    if (framed_size(out) < 8) {
        FAIL("imported CXCol framed size implausibly small: %u",
             framed_size(out));
    }
    p_arrow_free(out);
    cx_free(buf);
    PASS("test_arrow_round_trip");
}

static void test_arrow_null_inputs(void) {
    struct ArrowArrayStream stream;
    memset(&stream, 0, sizeof(stream));

    /* (a) NULL data_bin */
    char *err = NULL;
    char *rc = p_arrow_export(NULL, &stream, &err);
    if (rc) FAIL("export(NULL data_bin) returned non-NULL");
    if (!err) FAIL("export(NULL data_bin) did not set err_out");
    p_arrow_free(err);
    err = NULL;

    /* (b) NULL stream out */
    char *buf = make_chunked_buffer();
    if (!buf) FAIL("setup");
    rc = p_arrow_export(buf, NULL, &err);
    if (rc) FAIL("export(NULL stream) returned non-NULL");
    if (!err) FAIL("export(NULL stream) did not set err_out");
    p_arrow_free(err);
    err = NULL;
    cx_free(buf);

    /* (c) NULL stream in to import */
    char *out = p_arrow_import(NULL, &err);
    if (out) FAIL("import(NULL stream) returned non-NULL");
    if (!err) FAIL("import(NULL stream) did not set err_out");
    p_arrow_free(err);

    PASS("test_arrow_null_inputs");
}

/* ── Tests: schema validator (cx_validate + S008 RE2) ─────────────────── */

static const char SAMPLE_VALIDATE_DOC[] = "[server host='localhost' port=8080]";
static const char SAMPLE_VALIDATE_SCHEMA[] =
    "[?cx schema-of server]\n"
    "[server\n"
    "  [body elem]\n"
    "  [attr host::string [req]]\n"
    "  [attr port::i32 [req]]\n"
    "]\n";

static const char SAMPLE_VALIDATE_BAD_DOC[] = "[server port=8080]"; /* missing host */

static const char SAMPLE_VALIDATE_RE2_SCHEMA[] =
    "[?cx schema-of x]\n"
    "[x\n"
    "  [body elem]\n"
    "  [attr name::string [pattern '\\w+']]\n"
    "]\n";
static const char SAMPLE_VALIDATE_RE2_OK[]  = "[x name='hello']";
static const char SAMPLE_VALIDATE_RE2_BAD[] = "[x name='hello world!']";

static uint32_t diag_count(const char *framed) {
    /* Skip 4-byte framing prefix; next 4 bytes are diag count LE. */
    const unsigned char *p = (const unsigned char *)framed + 4;
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void test_validate_happy_path(void) {
    char *err = NULL;
    char *framed = cx_validate(SAMPLE_VALIDATE_DOC, SAMPLE_VALIDATE_SCHEMA, &err);
    if (!framed) FAIL("cx_validate returned NULL: %s", err ? err : "(null)");
    if (err) FAIL("cx_validate set err on success: %s", err);
    if (diag_count(framed) != 0) FAIL("expected 0 diags, got %u", diag_count(framed));
    cx_free(framed);
    PASS("test_validate_happy_path");
}

static void test_validate_error_path(void) {
    char *err = NULL;
    char *framed = cx_validate(SAMPLE_VALIDATE_BAD_DOC, SAMPLE_VALIDATE_SCHEMA, &err);
    if (!framed) FAIL("cx_validate returned NULL: %s", err ? err : "(null)");
    if (diag_count(framed) != 1) FAIL("expected 1 diag (S002), got %u", diag_count(framed));
    cx_free(framed);
    PASS("test_validate_error_path");
}

static void test_validate_with_len(void) {
    char *err = NULL;
    char *framed = cx_validate_with_len(
        SAMPLE_VALIDATE_DOC, sizeof(SAMPLE_VALIDATE_DOC) - 1,
        SAMPLE_VALIDATE_SCHEMA, sizeof(SAMPLE_VALIDATE_SCHEMA) - 1, &err);
    if (!framed) FAIL("cx_validate_with_len returned NULL: %s", err ? err : "(null)");
    if (diag_count(framed) != 0) FAIL("expected 0 diags, got %u", diag_count(framed));
    cx_free(framed);
    PASS("test_validate_with_len");
}

static void test_validate_re2_pattern(void) {
    char *err = NULL;
    /* Happy path. */
    char *ok_framed = cx_validate(SAMPLE_VALIDATE_RE2_OK, SAMPLE_VALIDATE_RE2_SCHEMA, &err);
    if (!ok_framed) FAIL("cx_validate (RE2 ok) NULL: %s", err ? err : "(null)");
    if (diag_count(ok_framed) != 0) FAIL("RE2 ok: expected 0 diags, got %u", diag_count(ok_framed));
    cx_free(ok_framed);
    /* Mismatch path (S008). */
    char *bad_framed = cx_validate(SAMPLE_VALIDATE_RE2_BAD, SAMPLE_VALIDATE_RE2_SCHEMA, &err);
    if (!bad_framed) FAIL("cx_validate (RE2 bad) NULL: %s", err ? err : "(null)");
    if (diag_count(bad_framed) != 1) FAIL("RE2 bad: expected 1 diag, got %u", diag_count(bad_framed));
    cx_free(bad_framed);
    PASS("test_validate_re2_pattern");
}

/* ── main ─────────────────────────────────────────────────────────────── */

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <path-to-libcx_arrow>\n", argv[0]);
        return 2;
    }
    if (load_libcx_arrow(argv[1]) != 0) return 1;

    /* libcx surface */
    test_chunked_happy_path();
    test_chunked_error_path();
    test_table_reader_open_and_close();
    test_table_reader_bad_input();
    test_table_reader_writer_round_trip();
    test_null_safe_close();

    /* schema validator surface */
    test_validate_happy_path();
    test_validate_error_path();
    test_validate_with_len();
    test_validate_re2_pattern();

    /* libcx_arrow surface (dlopen'd) */
    test_arrow_capability_and_version();
    test_arrow_round_trip();
    test_arrow_null_inputs();

    if (g_arrow_lib) dlclose(g_arrow_lib);

    if (g_failed) {
        fprintf(stderr, "FAIL: one or more tests failed\n");
        return 1;
    }
    printf("PASS: all c_abi_test cases\n");
    return 0;
}
