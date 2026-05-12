package cx;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Function;

/**
 * Tree-mutation helpers used by {@link CXDocument#transform} /
 * {@link CXDocument#transformAll}.
 *
 * <p>The CXPath parser, lexer, predicate types, and evaluator that
 * lived here were deleted in Phase 4 (CB-5): expression evaluation now
 * runs in libcx via {@code cx_select_all_paths}, and bindings navigate
 * the returned structural paths against their in-memory tree. What
 * remains here is host-language tree manipulation — not duplication.
 */
public final class CXPath {

    private CXPath() {}

    /** Return a copy of {@code e} with independent attrs/items lists so
     *  a caller's {@code f} cannot mutate the source. Attr instances
     *  are deep-copied (since setAttr mutates the existing Attr's
     *  value field, sharing them would let f reach back to the source). */
    public static Element elemDetached(Element e) {
        Element copy = new Element(e.name);
        copy.anchor   = e.anchor;
        copy.merge    = e.merge;
        copy.dataType = e.dataType;
        copy.attrs    = new ArrayList<>();
        for (Attr a : e.attrs) copy.attrs.add(new Attr(a.name, a.value, a.dataType));
        copy.items    = new ArrayList<>(e.items);
        return copy;
    }

    /** Functional replace of d.elements[idx]. */
    public static CXDocument docReplaceAt(CXDocument d, int idx, Element el) {
        CXDocument out = new CXDocument();
        out.elements = new ArrayList<>(d.elements);
        if (idx >= 0 && idx < out.elements.size()) {
            out.elements.set(idx, el);
        }
        out.prolog  = new ArrayList<>(d.prolog);
        out.doctype = d.doctype;
        return out;
    }

    /** Functional replace of e.items[idx]. */
    public static Element elemReplaceItemAt(Element e, int idx, Node child) {
        Element copy = new Element(e.name);
        copy.anchor   = e.anchor;
        copy.merge    = e.merge;
        copy.dataType = e.dataType;
        copy.attrs    = e.attrs;
        copy.items    = new ArrayList<>(e.items);
        if (idx >= 0 && idx < copy.items.size()) {
            copy.items.set(idx, child);
        }
        return copy;
    }

    /** Slash-path-style descent for {@link CXDocument#transform}. */
    public static Element pathCopyElement(Element e, String[] parts, Function<Element, Element> f) {
        for (int i = 0; i < e.items.size(); i++) {
            if (e.items.get(i) instanceof Element item && item.name.equals(parts[0])) {
                if (parts.length == 1) {
                    return elemReplaceItemAt(e, i, f.apply(elemDetached(item)));
                }
                Element updated = pathCopyElement(item,
                        java.util.Arrays.copyOfRange(parts, 1, parts.length), f);
                if (updated != null) return elemReplaceItemAt(e, i, updated);
                return null;
            }
        }
        return null;
    }

    // ── Path-based navigation (CB-5 / Phase 4) ────────────────────────────────

    /**
     * Walk {@code path} (indices into Document.elements then Element.items)
     * and return the live element reference at that position. Returns
     * null if any step is out-of-bounds or hits a non-Element item.
     */
    public static Element navigateDocPath(CXDocument d, int[] path) {
        if (path.length == 0 || path[0] < 0 || path[0] >= d.elements.size()) return null;
        Node node = d.elements.get(path[0]);
        for (int i = 1; i < path.length; i++) {
            if (!(node instanceof Element el)) return null;
            int k = path[i];
            if (k < 0 || k >= el.items.size()) return null;
            node = el.items.get(k);
        }
        return (node instanceof Element el) ? el : null;
    }

    /**
     * Return a new {@link CXDocument} with the element at {@code path}
     * replaced by {@code newElem}. Only the spine along {@code path} is
     * rebuilt; the original document is unchanged.
     */
    public static CXDocument replaceAtDocPath(CXDocument d, int[] path, Element newElem) {
        if (path.length == 0) return d;
        CXDocument out = new CXDocument();
        out.elements = new ArrayList<>(d.elements);
        out.prolog   = new ArrayList<>(d.prolog);
        out.doctype  = d.doctype;
        if (path.length == 1) {
            if (path[0] >= 0 && path[0] < out.elements.size()) {
                out.elements.set(path[0], newElem);
            }
        } else if (out.elements.get(path[0]) instanceof Element top) {
            int[] rest = java.util.Arrays.copyOfRange(path, 1, path.length);
            out.elements.set(path[0], replaceInElement(top, rest, newElem));
        }
        return out;
    }

    private static Element replaceInElement(Element el, int[] path, Element newElem) {
        if (path.length == 0) return newElem;
        Element copy = new Element(el.name);
        copy.anchor   = el.anchor;
        copy.merge    = el.merge;
        copy.dataType = el.dataType;
        copy.attrs    = el.attrs;
        copy.items    = new ArrayList<>(el.items);
        if (path.length == 1) {
            if (path[0] >= 0 && path[0] < copy.items.size()) {
                copy.items.set(path[0], newElem);
            }
        } else if (copy.items.get(path[0]) instanceof Element child) {
            int[] rest = java.util.Arrays.copyOfRange(path, 1, path.length);
            copy.items.set(path[0], replaceInElement(child, rest, newElem));
        }
        return copy;
    }
}
