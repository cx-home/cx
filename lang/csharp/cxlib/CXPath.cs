using System;
using System.Collections.Generic;

namespace CX;

/// <summary>
/// Tree-mutation helpers used by <see cref="CXDocument.Transform"/> /
/// <see cref="CXDocument.TransformAll"/>.
///
/// <para>The CXPath parser, lexer, predicate types, and evaluator that
/// lived here were deleted in Phase 4 (CB-5): expression evaluation
/// now runs in libcx via <c>cx_select_all_paths</c>, and bindings
/// navigate the returned structural paths against their in-memory tree.
/// What remains here is host-language tree manipulation — not
/// duplication.</para>
/// </summary>
public static class CXPath
{
    /// <summary>Return a copy of <paramref name="e"/> with independent
    /// attrs/items lists. Attr is a record (value-equal, immutable);
    /// the shallow list copy is safe because SetAttr replaces entries,
    /// it doesn't mutate them.</summary>
    public static Element ElemDetached(Element e)
    {
        var copy = new Element(e.Name)
        {
            Anchor = e.Anchor,
            Merge = e.Merge,
            DataType = e.DataType,
        };
        copy.Attrs = new List<Attr>(e.Attrs);
        copy.Items = new List<Node>(e.Items);
        return copy;
    }

    /// <summary>Functional replace of d.Elements[idx].</summary>
    public static CXDocument DocReplaceAt(CXDocument d, int idx, Element el)
    {
        var newElements = new List<Node>(d.Elements);
        if (idx >= 0 && idx < newElements.Count) newElements[idx] = el;
        return new CXDocument { Elements = newElements, Prolog = d.Prolog, Doctype = d.Doctype };
    }

    /// <summary>Functional replace of e.Items[idx].</summary>
    public static Element ElemReplaceItemAt(Element e, int idx, Node child)
    {
        var newItems = new List<Node>(e.Items);
        if (idx >= 0 && idx < newItems.Count) newItems[idx] = child;
        return new Element(e.Name)
        {
            Anchor = e.Anchor,
            Merge = e.Merge,
            DataType = e.DataType,
            Attrs = e.Attrs,
            Items = newItems,
        };
    }

    /// <summary>Slash-path-style descent for <see cref="CXDocument.Transform"/>.</summary>
    public static Element? PathCopyElement(Element e, string[] parts, Func<Element, Element> f)
    {
        for (int i = 0; i < e.Items.Count; i++)
        {
            if (e.Items[i] is Element item && item.Name == parts[0])
            {
                if (parts.Length == 1)
                    return ElemReplaceItemAt(e, i, f(ElemDetached(item)));
                var updated = PathCopyElement(item, parts[1..], f);
                if (updated is not null)
                    return ElemReplaceItemAt(e, i, updated);
                return null;
            }
        }
        return null;
    }

    // ── Path-based navigation (CB-5 / Phase 4) ────────────────────────────────

    /// <summary>
    /// Walk <paramref name="path"/> (indices into Document.Elements then
    /// Element.Items) and return the live element reference at that
    /// position. Returns null if any step is out-of-bounds or hits a
    /// non-Element item.
    /// </summary>
    public static Element? NavigateDocPath(CXDocument d, int[] path)
    {
        if (path.Length == 0 || path[0] < 0 || path[0] >= d.Elements.Count) return null;
        Node node = d.Elements[path[0]];
        for (int i = 1; i < path.Length; i++)
        {
            if (node is not Element el) return null;
            int k = path[i];
            if (k < 0 || k >= el.Items.Count) return null;
            node = el.Items[k];
        }
        return node as Element;
    }

    /// <summary>
    /// Return a new <see cref="CXDocument"/> with the element at
    /// <paramref name="path"/> replaced by <paramref name="newElem"/>.
    /// Only the spine along <paramref name="path"/> is rebuilt; the
    /// original document is unchanged.
    /// </summary>
    public static CXDocument ReplaceAtDocPath(CXDocument d, int[] path, Element newElem)
    {
        if (path.Length == 0) return d;
        var newElements = new List<Node>(d.Elements);
        if (path.Length == 1)
        {
            if (path[0] >= 0 && path[0] < newElements.Count)
                newElements[path[0]] = newElem;
        }
        else if (newElements[path[0]] is Element top)
        {
            var rest = path[1..];
            newElements[path[0]] = ReplaceInElement(top, rest, newElem);
        }
        return new CXDocument { Elements = newElements, Prolog = d.Prolog, Doctype = d.Doctype };
    }

    private static Element ReplaceInElement(Element el, int[] path, Element newElem)
    {
        if (path.Length == 0) return newElem;
        var newItems = new List<Node>(el.Items);
        if (path.Length == 1)
        {
            if (path[0] >= 0 && path[0] < newItems.Count) newItems[path[0]] = newElem;
        }
        else if (newItems[path[0]] is Element child)
        {
            var rest = path[1..];
            newItems[path[0]] = ReplaceInElement(child, rest, newElem);
        }
        return new Element(el.Name)
        {
            Anchor = el.Anchor,
            Merge = el.Merge,
            DataType = el.DataType,
            Attrs = el.Attrs,
            Items = newItems,
        };
    }
}
