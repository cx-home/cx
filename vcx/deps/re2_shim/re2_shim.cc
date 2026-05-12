// libcx RE2 shim — C-callable wrapper around C++ re2::RE2.
// See re2_shim.h for the contract.

#include "re2_shim.h"
#include <re2/re2.h>
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
