// Iterator value kind (kind) (wire format).
// W3f Tier-1 binding wrapper (v0.8.0).
//
// The V core renderer materialises iterators at the host emit boundary
// (W3c), so EvalCode returns a rendered string — never an IteratorNode
// directly. This type is observable when ast_bin acts as transport
// between CX-aware consumers (cxbin payloads, persisted caches,
// cross-binding handoff).

package cxlib

import (
	"fmt"
)

// IteratorSourceKind catalogues which generator backs an IteratorNode.
// Ordinals MUST mirror `vcx/cx/ast.v` `IteratorSourceKind`.
// Future kinds (`iter_file`, `iter_channel`) extend the
// table additively; v0.8.0 producers MUST emit only ordinals 0..16
type IteratorSourceKind uint8

const (
	IterNone      IteratorSourceKind = 0
	IterRange     IteratorSourceKind = 1
	IterMap       IteratorSourceKind = 2
	IterFilter    IteratorSourceKind = 3
	IterTake      IteratorSourceKind = 4
	IterDrop      IteratorSourceKind = 5
	IterConcat    IteratorSourceKind = 6
	IterChain     IteratorSourceKind = 7
	IterZip       IteratorSourceKind = 8
	IterEnumerate IteratorSourceKind = 9
	IterChunks    IteratorSourceKind = 10
	IterCycle     IteratorSourceKind = 11
	IterScan      IteratorSourceKind = 12
	IterFlatten   IteratorSourceKind = 13
	IterPartition IteratorSourceKind = 14
	IterGroupBy   IteratorSourceKind = 15
	IterReduce    IteratorSourceKind = 16
)

// IterKindName returns the spec name for an IteratorSourceKind ordinal,
// matching `vcx/cx/ast.v` IteratorSourceKind member names.
func IterKindName(k IteratorSourceKind) string {
	switch k {
	case IterNone:
		return "iter_none"
	case IterRange:
		return "iter_range"
	case IterMap:
		return "iter_map"
	case IterFilter:
		return "iter_filter"
	case IterTake:
		return "iter_take"
	case IterDrop:
		return "iter_drop"
	case IterConcat:
		return "iter_concat"
	case IterChain:
		return "iter_chain"
	case IterZip:
		return "iter_zip"
	case IterEnumerate:
		return "iter_enumerate"
	case IterChunks:
		return "iter_chunks"
	case IterCycle:
		return "iter_cycle"
	case IterScan:
		return "iter_scan"
	case IterFlatten:
		return "iter_flatten"
	case IterPartition:
		return "iter_partition"
	case IterGroupBy:
		return "iter_group_by"
	case IterReduce:
		return "iter_reduce"
	}
	return fmt.Sprintf("iter_unknown_%d", k)
}

// IteratorNode is the Iterator value kind. It carries
// `SourceKind` (the IteratorSourceKind ordinal), `SourceArgs` (the
// evaluated source AST nodes), and `SingleUse` (reserved
// for external-stream sources like `iter_file` / `iter_channel`).
//
// Identity is by Go pointer: two distinct
// `*IteratorNode` values compare unequal even when their source shapes
// match, mirroring the V core's pointer-identity semantics and the
// wire-roundtrip note. Use SeqEqual / EqualByShape to
// compare iterators by their walk output rather than identity.
//
// At v0.8.0 the binding has no re-evaluation handle into libcx (no
// `cx_iterator_pull` C ABI yet), so Next / Materialize yield only the
// memoised items already populated by the producer. The eager-materialise
// renderer path (W3c) is the public emit channel; a follow-on spec change
// will design the per-iterator pull export to enable true lazy
// traversal in the binding.
type IteratorNode struct {
	SourceKind IteratorSourceKind
	SourceArgs []Node
	// SingleUse. The W3a/W3c source kinds all
	// construct with false; reserved slot for external-stream kinds.
	SingleUse bool
	// Runtime-derived; NOT carried on the wire. A
	// producer (e.g. test scaffolding) may pre-populate Memo to expose
	// materialised items via Materialize() / Next().
	Memo      []Node
	Exhausted bool
	walkCount int
}

func (n *IteratorNode) cxNode() {}

// KindName returns the spec name of n.SourceKind.
func (n *IteratorNode) KindName() string { return IterKindName(n.SourceKind) }

// Next walks the iterator one step. Returns (item, true) while items
// remain; (nil, false) on exhaustion. Raises a re-walk error via
// returning (nil, false) immediately on single-use iterators already
// walked — callers can detect via WalkCount() == 0 before the call.
//
// TODO lazy-pull: once libcx exposes a per-iterator
// `cx_iterator_pull` C ABI export, replace this memo-only walk with
// a chunked pull loop. v0.8.0 W3f scope is wire-format round-trip +
// type surface.
func (n *IteratorNode) Next() (Node, bool) {
	if n.SingleUse && n.walkCount >= len(n.Memo) && n.Exhausted {
		// Re-walk attempt after exhaustion on a single-use source.
		return nil, false
	}
	if n.walkCount < len(n.Memo) {
		out := n.Memo[n.walkCount]
		n.walkCount++
		return out, true
	}
	// No memo to pull from at v0.8.0 (no cx_iterator_pull).
	n.Exhausted = true
	return nil, false
}

// Materialize eagerly walks the iterator to a slice. Idempotent on
// multi-use iterators; on single-use iterators it consumes the memo
// once and subsequent calls return nil.
func (n *IteratorNode) Materialize() []Node {
	if n.SingleUse && n.walkCount > 0 {
		return nil
	}
	out := make([]Node, 0, len(n.Memo))
	for {
		item, ok := n.Next()
		if !ok {
			break
		}
		out = append(out, item)
	}
	return out
}

// WalkCount reports how many items have been pulled so far. Useful for
// callers detecting single-use re-walk attempts before calling Next.
func (n *IteratorNode) WalkCount() int { return n.walkCount }

// Reset rewinds a multi-use iterator's walk pointer. Returns an error
// on single-use iterators.
func (n *IteratorNode) Reset() error {
	if n.SingleUse {
		return fmt.Errorf("CXER0105: cannot reset single-use iterator")
	}
	n.walkCount = 0
	return nil
}

func (n *IteratorNode) String() string {
	state := "lazy"
	if n.Exhausted {
		state = "materialised"
	}
	return fmt.Sprintf("IteratorNode(%s, %d items, %s)",
		n.KindName(), len(n.Memo), state)
}
