package cx

import com.sun.jna.Library
import com.sun.jna.Native
import org.junit.jupiter.api.Test
import kotlin.test.assertContains
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertTrue

import java.nio.file.Files
import java.nio.file.Path

/**
 * Streaming Table API tests for the Kotlin binding (Phase 7.74b-cont).
 *
 * Mirrors lang/python/test_streaming_table.py:
 *   1. cx_to_data_bin_chunked one-shot round-trip.
 *   2. bytes-mode round-trip: chunked emit → reader → writer → re-decode.
 *   3. fd-mode round-trip via temp file.
 *   4. invalid framed buffer raises an error.
 */
class StreamingTableTest {

    private val sixRowInput = """
        |[points :table[name:string score:i32]
        |  alice 91
        |  bob 88
        |  carol 73
        |  dave 95
        |  eve 84
        |  frank 60
        |]""".trimMargin()

    @Test fun toDataBinChunkedRoundTrip() {
        val framed = CxLib.toDataBinChunked(sixRowInput)
        assertTrue(framed.size > 4, "framed buffer should be non-empty")
        val cxText = CxLib.fromDataBin(framed)
        assertContains(cxText, "alice")
        assertContains(cxText, "frank")
    }

    @Test fun streamingTableBytesRoundTrip() {
        val framed = CxLib.toDataBinChunked(sixRowInput)
        val groups: List<ByteArray>
        val schema: ByteArray
        TableReader(framed).use { r ->
            schema = r.schema()
            groups = r.toList()
        }
        assertTrue(groups.isNotEmpty(), "no row groups")

        val out: ByteArray = TableWriter(schema).use { w ->
            for (g in groups) w.emit(g)
            w.closeGetBytes()
        }
        assertTrue(out.size > 4, "closeGetBytes returned empty buffer")
        val cxText = CxLib.fromDataBin(out)
        assertContains(cxText, "alice")
        assertContains(cxText, "frank")
    }

    @Test fun streamingTableFdRoundTrip() {
        val framed = CxLib.toDataBinChunked(sixRowInput)
        val groups: List<ByteArray>
        val schema: ByteArray
        TableReader(framed).use { r ->
            schema = r.schema()
            groups = r.toList()
        }

        // JDK 21 module system blocks reflective access to FileDescriptor.fd,
        // so go through libc open()/close() for the fd round-trip.
        val fdPath: Path = Files.createTempFile("cx_streaming_table_kt_", ".cxdb")
        try {
            val wfd = Posix.LIB.open(fdPath.toString(), Posix.O_WRONLY or Posix.O_TRUNC, 0)
            assertTrue(wfd >= 0, "POSIX open(write) failed: $wfd errno=${Native.getLastError()}")
            try {
                TableWriter.toFd(schema, wfd).use { w ->
                    for (g in groups) w.emit(g)
                }   // close() flushes end-of-table
            } finally { Posix.LIB.close(wfd) }

            assertTrue(Files.size(fdPath) > 0, "writer produced empty file")
            val rfd = Posix.LIB.open(fdPath.toString(), Posix.O_RDONLY, 0)
            assertTrue(rfd >= 0, "POSIX open(read) failed: $rfd errno=${Native.getLastError()}")
            val rtSchema: ByteArray
            val rtGroups: List<ByteArray>
            try {
                TableReader.fromFd(rfd).use { r ->
                    rtSchema = r.schema()
                    rtGroups = r.toList()
                }
            } finally { Posix.LIB.close(rfd) }

            assertContentEquals(schema, rtSchema, "fd schema drift")
            assertEquals(groups.size, rtGroups.size, "fd group count drift")
        } finally {
            Files.deleteIfExists(fdPath)
        }
    }

    @Test fun readerInvalidInputRaises() {
        val bad = byteArrayOf(0x04, 0x00, 0x00, 0x00, 'g'.code.toByte(), 'a'.code.toByte(),
                              'r'.code.toByte(), 'b'.code.toByte())
        assertFails {
            TableReader(bad).use { /* no-op */ }
        }
    }

    private interface Posix : Library {
        fun open (path: String, flags: Int, mode: Int): Int
        fun close(fd: Int): Int

        companion object {
            val LIB: Posix = Native.load("c", Posix::class.java)
            private val MAC = System.getProperty("os.name", "").lowercase().contains("mac")
            const val O_RDONLY = 0
            const val O_WRONLY = 1
            val O_TRUNC = if (MAC) 0x0400 else 0x0200    // mac/BSD vs Linux
        }
    }
}
