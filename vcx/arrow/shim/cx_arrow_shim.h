/* cx_arrow_shim.h — C prototypes for the Parquet + Arrow IPC file shim.
 *
 * Included by the V wrapper (arrow_files_d_cx_arrow_files.v) so the generated
 * C sees real declarations; the definitions live in cx_arrow_shim.cc and link
 * from target/libcx_arrow_shim.a. Stream params are `void*` to match V's
 * `voidptr`; the .cc treats them as `struct ArrowArrayStream*` (ABI-identical).
 *
 * Each returns 0 on success, non-zero on failure with *err set to a malloc'd
 * message the caller frees.
 */

#ifndef CX_ARROW_SHIM_H
#define CX_ARROW_SHIM_H

#ifdef __cplusplus
extern "C" {
#endif

int cx_pq_write_stream(void* stream_in, const char* path, char** err);
int cx_pq_read_stream(const char* path, void* stream_out, char** err);
int cx_ipc_write_stream(void* stream_in, const char* path, char** err);
int cx_ipc_read_stream(const char* path, void* stream_out, char** err);

#ifdef __cplusplus
}
#endif

#endif /* CX_ARROW_SHIM_H */
