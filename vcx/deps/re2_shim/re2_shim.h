/* libcx RE2 shim — C-callable wrapper around C++ re2::RE2.
 *
 * Phase 7.74c-schema-validator-v-core (ADR 0009 + spec/schema.md §7).
 * Used by the V core schema validator's S008 pattern check; bindings
 * never call this header directly — they go through cx_validate /
 * cx_validate_apply_defaults via the C ABI, so RE2's regex semantics
 * are centralised at the libcx boundary and identical across all
 * language bindings (per the locked decision in spec/abi.md §3 and
 * spec/schema.md §7).
 *
 * Linkage: depends on system RE2 (Homebrew `re2` on macOS /
 * `libre2-dev` on Debian/Ubuntu) at v0.6.0; vendored-submodule path
 * is queued post-tag for full source-pin determinism. The C++
 * exception machinery is suppressed at this boundary: every entry
 * point either succeeds or returns a NULL/ZERO sentinel.
 */

#ifndef CX_RE2_SHIM_H
#define CX_RE2_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle. */
typedef struct cx_re2 cx_re2;

/* Compile `pattern` as an RE2 anchored-or-unanchored regex. Returns
 * NULL on parse / unsupported-feature failure. The caller releases
 * the handle with cx_re2_destroy. */
cx_re2 *cx_re2_compile(const char *pattern);

/* Return 1 when `text` (length `text_len`) fully matches the pattern;
 * 0 otherwise. Full-match semantics align with spec/schema.md §7
 * `:pat='...'` ("must match the regex" — the schema author writes
 * `^...$` for partial matches, but the validator treats `:pat` as a
 * full-match by default since that's the common-case schema
 * authoring pattern). Returns 0 when `re == NULL`.
 *
 * The text-length variant avoids a NUL-scan on long inputs. */
int cx_re2_full_match(cx_re2 *re, const char *text, unsigned long text_len);

/* Return 1 when the regex matches anywhere in `text`; 0 otherwise.
 * Backs XPath 4.0 fn:matches — the schema validator uses the full-
 * match variant above; fn:matches uses partial semantics so an
 * unanchored pattern like `[0-9]+` matches any input that contains
 * a digit run. v0.7.0 C5 (regex family). */
int cx_re2_partial_match(cx_re2 *re, const char *text, unsigned long text_len);

/* Find the next match starting at `start_offset` in `text`. On match,
 * writes the match start/end byte offsets to *out_start / *out_end
 * and returns 1. On no-match, returns 0 and leaves the out params
 * unchanged. Used by V-side tokenize / split implementations that
 * iterate matches without allocating intermediate arrays at the
 * shim boundary. v0.7.0 C5 (regex family). */
int cx_re2_find(cx_re2 *re, const char *text, unsigned long text_len,
                unsigned long start_offset,
                unsigned long *out_start, unsigned long *out_end);

/* Replace every non-overlapping match of the pattern in `text` with
 * `replacement` (RE2 replacement syntax: `\1`..`\9` back-refs etc.).
 * Returns a malloc'd NUL-terminated buffer that the caller frees via
 * cx_re2_free_string, or NULL on internal failure (out-of-memory).
 * v0.7.0 C5 (regex family). */
char *cx_re2_replace_all(cx_re2 *re, const char *text, unsigned long text_len,
                         const char *replacement, unsigned long replacement_len);

/* Release a string returned by cx_re2_replace_all. Safe on NULL. */
void cx_re2_free_string(char *s);

/* Release the handle. Safe on NULL. */
void cx_re2_destroy(cx_re2 *re);

/* Library version string ("re2 0.YYYY.MM.DD" or similar) for
 * diagnostic purposes. */
const char *cx_re2_version(void);

#ifdef __cplusplus
}
#endif

#endif /* CX_RE2_SHIM_H */
