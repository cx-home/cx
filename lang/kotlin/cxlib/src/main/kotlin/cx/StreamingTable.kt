package cx

import com.sun.jna.Pointer
import com.sun.jna.ptr.PointerByReference

/**
 * Streaming Table reader / writer for the chunked-table CXDB format
 * (Phase 7.74a; spec/abi.md §2.10, ADR 0015 D8).
 *
 * Both classes implement [AutoCloseable] for use with `use { ... }`.
 *
 * Wire conventions:
 *   - In-memory variants consume / produce framed `[u32 LE size][CXDB payload]`.
 *   - fd variants operate on bare CXDB bytes (no size prefix).
 *
 * Col-spec exchange: framed ast_bin with one root Element 'table' and
 * one Attribute per column (name = column name, value = type-name).
 */

private fun readFramed(ptr: Pointer): ByteArray {
    val b0 = ptr.getByte(0).toInt() and 0xFF
    val b1 = ptr.getByte(1).toInt() and 0xFF
    val b2 = ptr.getByte(2).toInt() and 0xFF
    val b3 = ptr.getByte(3).toInt() and 0xFF
    val payloadSize = b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
    return ptr.getByteArray(0, 4 + payloadSize)
}

class TableReader private constructor(private var handle: Pointer?) : AutoCloseable, Iterable<ByteArray> {
    private var closed = false

    /** Open from a framed CXDB chunked-table buffer. */
    constructor(framedDataBin: ByteArray) : this(openBytes(framedDataBin))

    fun schema(): ByteArray {
        val h = handle ?: throw IllegalStateException("TableReader: handle closed")
        val err = PointerByReference()
        val ptr = CxLib.tableReaderSchema(h, err)
            ?: run {
                val ep  = err.value
                val msg = ep?.getString(0) ?: "cx_table_reader_schema: unknown error"
                if (ep != null) CxLib.cxFree(ep)
                throw RuntimeException(msg)
            }
        val out = readFramed(ptr)
        CxLib.cxFree(ptr)
        return out
    }

    /** Pull the next row group as framed `[u32 LE size][plain body]` bytes.
     *  Returns null on EOF; throws on error. */
    fun next(): ByteArray? {
        if (closed || handle == null) return null
        val err = PointerByReference()
        val ptr = CxLib.tableReaderNext(handle!!, err)
        if (ptr == null) {
            val ep = err.value
            if (ep != null) {
                val msg = ep.getString(0)
                CxLib.cxFree(ep)
                close()
                throw RuntimeException(msg)
            }
            return null     // EOF (err unset)
        }
        val out = readFramed(ptr)
        CxLib.cxFree(ptr)
        return out
    }

    override fun close() {
        if (closed) return
        closed = true
        handle?.let { CxLib.tableReaderClose(it); handle = null }
    }

    override fun iterator(): Iterator<ByteArray> {
        val outer = this
        return object : Iterator<ByteArray> {
            private var peeked: ByteArray? = null
            private var fetched = false
            private fun ensureFetched() {
                if (!fetched) { peeked = outer.next(); fetched = true }
            }
            override fun hasNext(): Boolean { ensureFetched(); return peeked != null }
            override fun next(): ByteArray {
                ensureFetched()
                val v = peeked ?: throw NoSuchElementException()
                peeked = null; fetched = false
                return v
            }
        }
    }

    companion object {
        /** Open from a file descriptor positioned at the start of a bare CXDB stream. */
        fun fromFd(fd: Int): TableReader {
            val err = PointerByReference()
            val h = CxLib.tableReaderOpenFd(fd, err)
                ?: run {
                    val ep  = err.value
                    val msg = ep?.getString(0) ?: "cx_table_reader_open_fd: unknown error"
                    if (ep != null) CxLib.cxFree(ep)
                    throw RuntimeException(msg)
                }
            return TableReader(h)
        }

        private fun openBytes(framed: ByteArray): Pointer {
            if (framed.isEmpty()) throw RuntimeException("cx_table_reader_open: empty input")
            val err = PointerByReference()
            return CxLib.tableReaderOpen(framed, err)
                ?: run {
                    val ep  = err.value
                    val msg = ep?.getString(0) ?: "cx_table_reader_open: unknown error"
                    if (ep != null) CxLib.cxFree(ep)
                    throw RuntimeException(msg)
                }
        }
    }
}

class TableWriter private constructor(private var handle: Pointer?, private val isFd: Boolean) : AutoCloseable {
    private var closed = false

    /** Open an in-memory writer; complete with [closeGetBytes]. */
    constructor(colSpecPayload: ByteArray) : this(openBytes(colSpecPayload), isFd = false)

    fun emit(rowGroupPayload: ByteArray) {
        val h = handle ?: throw IllegalStateException("TableWriter: handle closed")
        val err = PointerByReference()
        val ret = CxLib.tableWriterEmitRowGroup(h, rowGroupPayload, err)
        val ep = err.value
        if (ep != null) {
            val msg = ep.getString(0)
            CxLib.cxFree(ep)
            throw RuntimeException(msg)
        }
        if (ret != null) CxLib.cxFree(ret)
    }

    /** In-memory writers only: emit end-of-table and return the complete framed buffer. */
    fun closeGetBytes(): ByteArray {
        if (isFd) throw IllegalStateException(
            "closeGetBytes is for in-memory writers; use close() for fd writers")
        val h = handle ?: throw IllegalStateException("TableWriter: handle closed")
        val err = PointerByReference()
        val ptr = CxLib.tableWriterCloseGetBytes(h, err)
        // V core releases the handle inside close_get_bytes; mark closed.
        handle = null
        closed = true
        if (ptr == null) {
            val ep  = err.value
            val msg = ep?.getString(0) ?: "cx_table_writer_close_get_bytes: unknown error"
            if (ep != null) CxLib.cxFree(ep)
            throw RuntimeException(msg)
        }
        val out = readFramed(ptr)
        CxLib.cxFree(ptr)
        return out
    }

    override fun close() {
        if (closed) return
        closed = true
        handle?.let { CxLib.tableWriterClose(it); handle = null }
    }

    companion object {
        /** Open a streaming-fd writer; complete with [close] to flush end-of-table. */
        fun toFd(colSpecPayload: ByteArray, fd: Int): TableWriter {
            if (colSpecPayload.isEmpty()) throw RuntimeException("cx_table_writer_open_fd: empty col_spec_payload")
            val err = PointerByReference()
            val h = CxLib.tableWriterOpenFd(colSpecPayload, fd, err)
                ?: run {
                    val ep  = err.value
                    val msg = ep?.getString(0) ?: "cx_table_writer_open_fd: unknown error"
                    if (ep != null) CxLib.cxFree(ep)
                    throw RuntimeException(msg)
                }
            return TableWriter(h, isFd = true)
        }

        private fun openBytes(colSpec: ByteArray): Pointer {
            if (colSpec.isEmpty()) throw RuntimeException("cx_table_writer_open: empty col_spec_payload")
            val err = PointerByReference()
            return CxLib.tableWriterOpen(colSpec, err)
                ?: run {
                    val ep  = err.value
                    val msg = ep?.getString(0) ?: "cx_table_writer_open: unknown error"
                    if (ep != null) CxLib.cxFree(ep)
                    throw RuntimeException(msg)
                }
        }
    }
}
