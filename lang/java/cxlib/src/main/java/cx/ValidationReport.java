package cx;

import java.util.ArrayList;
import java.util.List;

/**
 * Result of a {@link CxLib#validate} / {@link CxLib#validateWithDefaults}
 * call. {@link #diagnostics} is the ordered list of findings;
 * {@link #modifiedDoc} carries the canonical CX text with schema-driven
 * defaults inserted (empty for plain {@code validate}, or when the
 * schema declares no defaults).
 */
public final class ValidationReport {
    public final List<Diagnostic> diagnostics;
    public final String           modifiedDoc;

    public ValidationReport(List<Diagnostic> diagnostics, String modifiedDoc) {
        this.diagnostics = diagnostics != null ? diagnostics : new ArrayList<>();
        this.modifiedDoc = modifiedDoc != null ? modifiedDoc : "";
    }

    public boolean isValid() {
        for (Diagnostic d : diagnostics) {
            if (d.severity() == Severity.ERROR) return false;
        }
        return true;
    }

    public int errorCount() { return countSeverity(Severity.ERROR); }
    public int warnCount () { return countSeverity(Severity.WARN);  }
    public int infoCount () { return countSeverity(Severity.INFO);  }

    public List<String> errorCodes() {
        List<String> out = new ArrayList<>();
        for (Diagnostic d : diagnostics) {
            if (d.severity() == Severity.ERROR) out.add(d.code());
        }
        return out;
    }

    private int countSeverity(Severity s) {
        int n = 0;
        for (Diagnostic d : diagnostics) if (d.severity() == s) n++;
        return n;
    }
}
