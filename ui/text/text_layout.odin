package text

import "core:mem"

import "../../base"

// Text layout works in the element / widget space, e.g.
// the constraints on how to layout the text is defined
// by the size of the widget / element the text is attached to.

Text_Metrics :: struct {
	width:       f32,
	ascent:      f32,
	descent:     f32,
	line_height: f32,
}

// Function pointer types for text measurement
Measure_Text_Proc :: proc(text: string, font_id: u16, user_data: rawptr) -> Text_Metrics

// TODO(Thomas): This is somewhat the signature of the old api, except this doesn't take in the ui Context.
// This is probably not what we want in the long term, but good for getting started in setting up a red line
// through the new text system.
measure_text_content :: proc(
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

Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Token :: struct {
	start:  int, // Byte start in original string
	length: int, // Length of the token in bytes
	width:  f32, // Measured width
	kind:   Token_Kind,
}

Text_Line :: struct {
	text:   string,
	start:  int, // Starting token idx
	length: int, // Length in number of tokens
	width:  f32, // Visual width
	height: f32, // Line height
}


Text_Layout :: struct {
	// Source reference, for cache validation
	text_hash:       u64,
	available_width: f32,
	font_id:         u16,

	// Tokenization results (cached)
	tokens:          [dynamic]Text_Token,

	// Line layouts
	lines:           [dynamic]Text_Line,
}

Text_Layout_Cache :: struct {}
