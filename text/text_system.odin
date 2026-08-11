package text

import "../base"

import "core:mem"

ASCII_TABLE_LEN :: 128

// TODO(Thomas): Does the fonts have to be [dynamic]
Text_System :: struct {
	measurement:  Text_Measurement,
	fonts:        [dynamic]Font_Cache,
	layout_cache: map[u64]Text_Layout_Cache_Entry,
	text_states:  map[u64]Text_State,
}

// TODO(Thomas): Taking in single Text_Measurement and using it like this won't work
// with multiple fonts.
@(require_results)
init_text_system :: proc(
	ts: ^Text_System,
	measurement: Text_Measurement,
	font_configs: []base.Font_Config,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {
	assert(measurement.measure_text_proc != nil)
	assert(measurement.measure_codepoint_proc != nil)

	ts.measurement = measurement
	ts.fonts = make([dynamic]Font_Cache, allocator) or_return

	for config, i in font_configs {
		fc: Font_Cache
		init_font_cache(&fc, i, measurement, allocator) or_return
		append(&ts.fonts, fc) or_return
	}

	ts.layout_cache = make(map[u64]Text_Layout_Cache_Entry, allocator)
	ts.text_states = make(map[u64]Text_State, allocator)

	return nil
}

deinit_text_system :: proc(ts: ^Text_System, allocator: mem.Allocator) {
	free_text_layout_cache_entries(ts.layout_cache, allocator)

	for &fc in ts.fonts {
		delete(fc.extended)
	}
	delete(ts.fonts)

	for _, &state in ts.text_states {
		deinit_text_state(&state)
	}
	delete(ts.text_states)
}

// TODO(Thomas): Think about unifying this with the pruning of UI_Elements.
// It seems to pretty much have the same condition??
@(require_results)
prune_text_system :: proc(
	ts: ^Text_System,
	frame_idx: u64,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) -> mem.Allocator_Error {

	// Cannot alter map while iterating, so we collect keys first.
	dead_keys := make([dynamic]u64, frame_allocator) or_return

	for key, state in ts.text_states {
		if state.last_frame_idx < frame_idx - 1 {
			append(&dead_keys, key)
		}
	}

	for key in dead_keys {
		state, found := &ts.text_states[key]
		assert(found)
		deinit_text_state(state)
		delete_key(&ts.text_states, key)
	}

	prune_text_layout_cache(
		&ts.layout_cache,
		frame_idx,
		persistent_allocator,
		frame_allocator,
	) or_return

	return nil
}

Font_Cache :: struct {
	ascent:      f32,
	descent:     f32,
	line_height: f32,
	ascii:       [ASCII_TABLE_LEN]Codepoint_Metrics,
	extended:    map[rune]Codepoint_Metrics,
}

init_font_cache :: proc(
	fc: ^Font_Cache,
	font_handle: Font_Handle,
	measurement: Text_Measurement,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {

	fc.extended = make(map[rune]Codepoint_Metrics, allocator)

	vertical_metrics := measurement.measure_text_proc("", font_handle, measurement.font_user_data)
	fc.ascent = vertical_metrics.ascent
	fc.descent = vertical_metrics.descent
	fc.line_height = vertical_metrics.line_height

	// fill ascii table
	for i in 0 ..< ASCII_TABLE_LEN {
		fc.ascii[i] = measurement.measure_codepoint_proc(
			rune(i),
			font_handle,
			measurement.font_user_data,
		)
	}

	return nil
}

@(require_results)
glyph_metrics :: proc(ts: ^Text_System, font_handle: Font_Handle, r: rune) -> Codepoint_Metrics {

	fc := &ts.fonts[font_handle]
	if r >= 0 && r < ASCII_TABLE_LEN {
		return fc.ascii[r]
	}

	if m, found := fc.extended[r]; found {
		return m
	}

	m := ts.measurement.measure_codepoint_proc(r, font_handle, ts.measurement.font_user_data)
	fc.extended[r] = m

	return m
}

@(require_results)
ascent :: proc(ts: ^Text_System, font_handle: Font_Handle) -> f32 {
	fc := &ts.fonts[font_handle]
	return fc.ascent
}

@(require_results)
descent :: proc(ts: ^Text_System, font_handle: Font_Handle) -> f32 {
	fc := &ts.fonts[font_handle]
	return fc.descent
}

@(require_results)
font_line_height :: proc(ts: ^Text_System, font_handle: Font_Handle) -> f32 {
	fc := &ts.fonts[font_handle]
	return fc.line_height
}
