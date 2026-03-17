package text

import "../base"

Font_Handle :: int

// Font-agnostic text measurement result
Text_Metrics :: struct {
	width:       f32,
	ascent:      f32,
	descent:     f32,
	line_height: f32,
}

// TODO(Thomas): This is very temporary, and should be replaced by glyph type eventually
// Font-agnostic codepoint metrics
Codepoint_Metrics :: struct {
	width:        f32,
	left_bearing: f32,
}

// Function pointer types for text measurement
Measure_Text_Proc :: proc(
	text: string,
	font_id: base.Font_Handle,
	user_data: rawptr,
) -> Text_Metrics

// Function pointer for glyph measurement
Measure_Code_Point_Proc :: proc(
	codepoint: rune,
	font_id: base.Font_Handle,
	user_data: rawptr,
) -> Codepoint_Metrics
