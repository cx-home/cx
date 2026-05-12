package cx;

/**
 * Severity of a single {@link Diagnostic} emitted by the schema validator.
 * Wire format byte: 0=Info, 1=Warn, 2=Error (spec/abi.md §2.13.2).
 */
public enum Severity {
    INFO, WARN, ERROR;

    static Severity fromU8(int v) {
        return switch (v) {
            case 0  -> INFO;
            case 1  -> WARN;
            default -> ERROR;
        };
    }
}
