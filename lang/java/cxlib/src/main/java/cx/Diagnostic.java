package cx;

/**
 * One validator finding (S-code, severity, message, source location).
 * Emitted by {@link CxLib#validate} / {@link CxLib#validateWithDefaults};
 * see spec/abi.md §2.13.2.
 *
 * <p>{@code line} / {@code col} carry unsigned 32-bit values from the
 * wire format (range 0 .. 2^32-1); they're stored as {@code long} to
 * avoid sign-extension surprises. v0.6.0 always emits 0:0 — line/col
 * threading is a separate phase that bumps the wire format.
 */
public record Diagnostic(
        String   code,
        Severity severity,
        String   message,
        long     line,
        long     col) {}
