import CXC
import Foundation

/// Pull-based iterator over CX streaming events backed by the
/// `cx_events_open` / `cx_events_next` / `cx_events_close` handle API.
/// Replaces the prior eager-buffered cx_to_events_bin path
/// (Phase 5 / CB-4).
///
/// Usage:
/// ```swift
///   let s = try EventStream(cxStr)
///   defer { s.close() }
///   while let ev = try s.next() {
///       if ev.type == "StartElement" { ... }
///   }
/// ```
public final class EventStream: Sequence, IteratorProtocol {

    private var handle: OpaquePointer?
    private var closed = false
    private var pendingError: Error?

    public init(_ cxStr: String) throws {
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let h = cxStr.withCString({ cx_events_open($0, &errPtr) }) else {
            let msg: String
            if let ep = errPtr { msg = String(cString: ep); cx_free(ep) }
            else                { msg = "cx_events_open: unknown error" }
            throw CXError.parse(msg)
        }
        self.handle = OpaquePointer(h)
    }

    deinit { close() }

    /// Pull the next event, or `nil` on EOF. Throws on error.
    public func nextEvent() throws -> StreamEvent? {
        if closed || handle == nil { return nil }
        var errPtr: UnsafeMutablePointer<CChar>? = nil
        guard let raw = cx_events_next(UnsafeMutableRawPointer(handle!), &errPtr) else {
            // NULL with err = error; NULL with no err = EOF.
            if let ep = errPtr {
                let msg = String(cString: ep)
                cx_free(ep)
                close()
                throw CXError.parse(msg)
            }
            close()
            return nil
        }
        let rawPtr = UnsafeRawPointer(raw)
        let sizeLE = rawPtr.load(as: UInt32.self)
        let size = Int(UInt32(littleEndian: sizeLE))
        let payload = Data(bytes: rawPtr.advanced(by: 4), count: size)
        cx_free(raw)
        return try BinaryDecoder.decodeOneEvent(payload)
    }

    /// `IteratorProtocol.next` — non-throwing wrapper. Stores any
    /// error on the stream; check `lastError` after iteration ends.
    public func next() -> StreamEvent? {
        do {
            return try nextEvent()
        } catch {
            pendingError = error
            return nil
        }
    }

    /// The last error encountered during iteration, if any.
    public var lastError: Error? { pendingError }

    /// Release the underlying handle. Idempotent.
    public func close() {
        if closed { return }
        closed = true
        if let h = handle {
            cx_events_close(UnsafeMutableRawPointer(h))
            handle = nil
        }
    }

    public func makeIterator() -> EventStream { self }
}
