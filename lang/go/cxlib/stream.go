package cxlib

// Stream returns all streaming events for a CX input string.
//
// v3.4 (Phase 5 / CB-4): pulls events one-by-one via the
// cx_events_open / cx_events_next / cx_events_close handle API.
// Replaces the prior eager-buffered cx_to_events_bin path. For true
// pull-based streaming with caller-controlled cancellation, use
// OpenEvents() / EventStream.Next() / EventStream.Close() directly.
func Stream(cxStr string) ([]StreamEvent, error) {
	s, err := OpenEvents(cxStr)
	if err != nil {
		return nil, err
	}
	defer s.Close()
	var events []StreamEvent
	for {
		evt, ok, err := s.Next()
		if err != nil {
			return nil, err
		}
		if !ok {
			break
		}
		events = append(events, evt)
	}
	return events, nil
}
