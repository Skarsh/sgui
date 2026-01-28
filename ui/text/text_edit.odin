package text

import "core:mem"

import "../../base"

Text_Metrics :: struct {
	width:       f32,
	ascent:      f32,
	descent:     f32,
	line_height: f32,
}

// Function pointer types for text measurement
Measure_Text_Proc :: proc(text: string, font_id: u16, user_data: rawptr) -> Text_Metrics

Text_Edit_State :: struct {
	buffer:            Text_Buffer,
	cursor:            int,
	measure_text_proc: Measure_Text_Proc,
}

text_edit_init :: proc(
	allocator: mem.Allocator = context.allocator,
	measure_text_proc: Measure_Text_Proc,
) -> Text_Edit_State {
	text_buf := text_buffer_init(allocator)
	return Text_Edit_State{buffer = text_buf, measure_text_proc = measure_text_proc}
}

// TODO(Thomas): This is somewhat the signature of the old api, except this doesn't take in the ui Context.
// This is probably not what we want in the long term, but good for getting started in setting up a red line
// through the new text system.
measure_text_content :: proc(
	text_edit_state: ^Text_Edit_State,
	text: string,
	font_id: u16,
	element_size: base.Vec2,
	allocator: mem.Allocator,
) -> (
	w: f32,
	h: f32,
	lines: [dynamic]Text_Line,
) {
	return
}
