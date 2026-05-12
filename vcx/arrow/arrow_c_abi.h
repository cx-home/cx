/* Arrow C-Data ABI struct definitions used by libcx_arrow.
 *
 * Mirrors https://arrow.apache.org/docs/format/CDataInterface.html and
 * https://arrow.apache.org/docs/format/CStreamInterface.html exactly so
 * that consumers (PyArrow, DuckDB, Polars, Arrow Java, ...) bind to the
 * same struct layout.
 *
 * libcx_arrow's V module references these via `struct C.ArrowSchema`
 * etc. — V does not emit struct definitions for `struct C.*`, so this
 * header is the source of truth for the layout.
 */

#ifndef LIBCX_ARROW_C_ABI_H
#define LIBCX_ARROW_C_ABI_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct ArrowSchema {
    const char* format;
    const char* name;
    const char* metadata;
    int64_t flags;
    int64_t n_children;
    struct ArrowSchema** children;
    struct ArrowSchema* dictionary;
    void (*release)(struct ArrowSchema*);
    void* private_data;
};

struct ArrowArray {
    int64_t length;
    int64_t null_count;
    int64_t offset;
    int64_t n_buffers;
    int64_t n_children;
    const void** buffers;
    struct ArrowArray** children;
    struct ArrowArray* dictionary;
    void (*release)(struct ArrowArray*);
    void* private_data;
};

struct ArrowArrayStream {
    int  (*get_schema)(struct ArrowArrayStream*, struct ArrowSchema* out);
    int  (*get_next)(struct ArrowArrayStream*, struct ArrowArray* out);
    const char* (*get_last_error)(struct ArrowArrayStream*);
    void (*release)(struct ArrowArrayStream*);
    void* private_data;
};

#ifdef __cplusplus
}
#endif

#endif /* LIBCX_ARROW_C_ABI_H */
