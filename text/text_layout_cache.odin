package text

import "core:hash"
import "core:mem"

Text_Layout_Cache_Request :: struct {
	key:              u64,
	frame_idx:        u64,
	text:             string,
	params:           Text_Layout_Params,
	text_measurement: Text_Measurement,
}

Text_Layout_Cache_Entry :: struct {
	text_hash:      u64,
	params:         Text_Layout_Params,
	// The frame the entry was last requested on, used by prune_text_layout_cache
	// to drop entries whose element has stopped being built.
	last_frame_idx: u64,
	layout:         Text_Layout,
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

@(require_results)
layout_text_cached :: proc(
	cache: ^map[u64]Text_Layout_Cache_Entry,
	req: Text_Layout_Cache_Request,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) -> (
	layout: Text_Layout,
	alloc_err: mem.Allocator_Error,
) {
	text_hash := hash.fnv64a(transmute([]u8)req.text)
	entry, found := &cache[req.key]

	if found && entry.text_hash == text_hash && entry.params == req.params {
		// Request and entry match, so the cached layout is still valid.
		entry.last_frame_idx = req.frame_idx
		layout = entry.layout
		return
	}

	// Cache is invalidated, we build the replacement layout before freeing, so that in case the allocation fails
	// we will still hold a entry in the cache.
	layout = layout_text(
		req.text,
		req.params,
		req.text_measurement,
		persistent_allocator,
		frame_allocator,
	) or_return

	if found {
		free_entry(entry, persistent_allocator)
	}

	cache[req.key] = Text_Layout_Cache_Entry {
		text_hash      = text_hash,
		params         = req.params,
		last_frame_idx = req.frame_idx,
		layout         = layout,
	}
	return
}

// Frees entreis that weren't requested on the last frame.
prune_text_layout_cache :: proc(
	cache: ^map[u64]Text_Layout_Cache_Entry,
	frame_idx: u64,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) {
	// Cannot alter the map while iterating, so we collect the dead keys first.
	dead_keys, alloc_err := make([dynamic]u64, frame_allocator)
	assert(alloc_err == .None)

	for key, entry in cache {
		if entry.last_frame_idx < frame_idx - 1 {
			_, alloc_err = append(&dead_keys, key)
			assert(alloc_err == .None)
		}
	}

	for key in dead_keys {
		entry := cache[key]
		free_entry(&entry, persistent_allocator)
		delete_key(cache, key)
	}
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
