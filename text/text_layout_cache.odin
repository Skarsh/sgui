package text

// Core idea:
// Receive layout cache request
// Retreive cache entry from the cache using the cache request key
// If non entry found, calculate new text layout using the cache request and insert a new entry
// If entry is found, compare against all non-key cache request parameters to see if it's
// a different request.
// If request is different, calculate new layout and insert entry for that key

Text_Layout_Cache_Request :: struct {
	key:       u64,
	text:      string,
	params:    Text_Layout_Params,
	// TODO(Thomas): Not sure about this one
	//text_measurement: Text_Measurement,
	// TODO(Thomas): Not entirely sure about the frame_idx,
	// the idea would be that doing multiple layouts at the
	// same frame for the same id should always return the same layout,
	// so by looking at the frame_idx, one could short-circuit that.
	frame_idx: u64,
}

Text_Layout_Cache_Entry :: struct {
	req:    Text_Layout_Cache_Request,
	layout: Text_Layout,
}

get_text_layout_cache :: proc(
	cache: ^map[u64]Text_Layout_Cache_Entry,
	req: Text_Layout_Cache_Request,
) -> Text_Layout {

	layout: Text_Layout
	entry, found := cache[req.key]

	if found {
		// Compare cache request fields to see if it has changed from
		if entry.req.text == req.text && entry.req.params == req.params {

			// Caching parameters in the request and the entry are equal
			// so we set the layout to the layout on the entry.
			layout = entry.layout

		} else {
			// Cache is invalidated, compute new layout and insert.
			// TODO(Thomas): Compute layout etc, construct the entry correctly.
			cache[req.key] = Text_Layout_Cache_Entry{}
		}
	} else {
		// Entry doesn't exist
		// TODO(Thomas): Compute layout etc, construct the entry correctly.
	}

	return layout
}
