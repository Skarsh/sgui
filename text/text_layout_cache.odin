package text

import "core:mem"

Text_Layout_Cache_Request :: struct {
	key:              u64,
	text:             string,
	params:           Text_Layout_Params,
	// TODO(Thomas): Not sure about this one
	text_measurement: Text_Measurement,
}

Text_Layout_Cache_Entry :: struct {
	req:    Text_Layout_Cache_Request,
	layout: Text_Layout,
}

@(require_results)
read_text_layout_cache :: proc(
	cache: map[u64]Text_Layout_Cache_Entry,
	key: u64,
) -> (
	Text_Layout,
	bool,
) {
	entry, found := cache[key]
	return entry.layout, found
}

// TODO(Thomas): Better name that makes it clear that this will invalidate
// cache etc.
@(require_results)
get_text_layout_cache :: proc(
	cache: ^map[u64]Text_Layout_Cache_Entry,
	req: Text_Layout_Cache_Request,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) -> (
	layout: Text_Layout,
	alloc_err: mem.Allocator_Error,
) {

	entry, found := cache[req.key]

	if found {
		// TODO(Thomas): Compare text_measurement as well?
		// Compare cache request fields to see if it has changed from
		if entry.req.text == req.text && entry.req.params == req.params {

			// Caching parameters in the request and the entry are equal
			// so we set the layout to the layout on the entry.
			layout = entry.layout

		} else {
			// Free the previous entry
			free_entry(&entry, persistent_allocator)

			// Cache is invalidated, compute new layout and insert.
			layout, alloc_err = layout_text(
				req.text,
				req.params,
				req.text_measurement,
				persistent_allocator,
				frame_allocator,
			)
			cache[req.key] = Text_Layout_Cache_Entry{req, layout}
		}
	} else {
		// Entry doesn't exist, create layout and set entry
		layout, alloc_err = layout_text(
			req.text,
			req.params,
			req.text_measurement,
			persistent_allocator,
			frame_allocator,
		)
		cache[req.key] = Text_Layout_Cache_Entry{req, layout}
	}

	return
}

@(private)
free_entry :: proc(entry: ^Text_Layout_Cache_Entry, allocator: mem.Allocator) {
	delete(entry.layout.rows, allocator)
	delete(entry.layout.glyphs, allocator)
}

free_text_layout_cache_entries :: proc(
	cache: map[u64]Text_Layout_Cache_Entry,
	allocator: mem.Allocator,
) {
	for _, &entry in cache {
		free_entry(&entry, allocator)
	}
}
