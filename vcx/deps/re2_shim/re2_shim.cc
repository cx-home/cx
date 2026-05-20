// libcx RE2 shim — C-callable wrapper around C++ re2::RE2.
// See re2_shim.h for the contract.

#include "re2_shim.h"
#include <re2/re2.h>
#include <cstdlib>
#include <cstring>
#include <string>

extern "C" {

struct cx_re2 {
    re2::RE2 *re;
};

cx_re2 *cx_re2_compile(const char *pattern) {
    if (!pattern) return nullptr;
    re2::RE2::Options opts;
    opts.set_log_errors(false);
    re2::RE2 *re = new re2::RE2(pattern, opts);
    if (!re->ok()) {
        delete re;
        return nullptr;
    }
    cx_re2 *h = new cx_re2;
    h->re = re;
    return h;
}

int cx_re2_full_match(cx_re2 *re, const char *text, unsigned long text_len) {
    if (!re || !re->re || !text) return 0;
    re2::StringPiece sp(text, static_cast<size_t>(text_len));
    return re2::RE2::FullMatch(sp, *re->re) ? 1 : 0;
}

int cx_re2_partial_match(cx_re2 *re, const char *text, unsigned long text_len) {
    if (!re || !re->re || !text) return 0;
    re2::StringPiece sp(text, static_cast<size_t>(text_len));
    return re2::RE2::PartialMatch(sp, *re->re) ? 1 : 0;
}

int cx_re2_find(cx_re2 *re, const char *text, unsigned long text_len,
                unsigned long start_offset,
                unsigned long *out_start, unsigned long *out_end) {
    if (!re || !re->re || !text || !out_start || !out_end) return 0;
    if (start_offset > text_len) return 0;
    re2::StringPiece sp(text + start_offset,
                        static_cast<size_t>(text_len - start_offset));
    re2::StringPiece match;
    if (!re->re->Match(sp, 0, sp.size(), re2::RE2::UNANCHORED, &match, 1)) {
        return 0;
    }
    *out_start = start_offset + (match.data() - sp.data());
    *out_end = *out_start + match.size();
    return 1;
}

char *cx_re2_replace_all(cx_re2 *re, const char *text, unsigned long text_len,
                         const char *replacement, unsigned long replacement_len) {
    if (!re || !re->re || !text || !replacement) return nullptr;
    std::string out(text, static_cast<size_t>(text_len));
    re2::StringPiece rep(replacement, static_cast<size_t>(replacement_len));
    re2::RE2::GlobalReplace(&out, *re->re, rep);
    char *buf = static_cast<char *>(std::malloc(out.size() + 1));
    if (!buf) return nullptr;
    std::memcpy(buf, out.data(), out.size());
    buf[out.size()] = '\0';
    return buf;
}

void cx_re2_free_string(char *s) {
    if (s) std::free(s);
}

void cx_re2_destroy(cx_re2 *re) {
    if (!re) return;
    delete re->re;
    delete re;
}

const char *cx_re2_version(void) {
    // RE2 doesn't ship a version macro; the package version is the
    // Homebrew/apt label. Diagnostic-only — bindings call this at
    // load time for the trace log.
    return "re2-system";
}

} // extern "C"
