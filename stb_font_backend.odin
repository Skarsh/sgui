package main

import "core:log"
import "core:os"

import stbtt "vendor:stb/truetype"

import ui "ui"

Font_Info :: stbtt.fontinfo

init_stb_font :: proc(font_info: ^stbtt.fontinfo, path: string) -> bool {
	font_data, font_ok := os.read_entire_file_from_filename(path)
	if !font_ok {
		log.error("Failed to load font file")
		return false
	}

	// Initialize font
	if !stbtt.InitFont(font_info, raw_data(font_data), 0) {
		log.error("Failed to initialize font")
		return false
	}

	return true
}

STB_Font_Context :: struct {
	font_info: ^stbtt.fontinfo,
}

stb_measure_text :: proc(
	text: string,
	font_id: u16,
	font_size: f32,
	user_data: rawptr,
) -> ui.Text_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info

	scale := stbtt.ScaleForPixelHeight(font_info, font_size)

	width: f32 = 0
	ascent, descent, line_gap: i32
	stbtt.GetFontVMetrics(font_info, &ascent, &descent, &line_gap)

	for r in text {
		advance_width, left_side_bearing: i32
		stbtt.GetCodepointHMetrics(font_info, r, &advance_width, &left_side_bearing)
		width += f32(advance_width) * scale
	}

	return ui.Text_Metrics {
		width = width,
		height = f32(ascent - descent) * scale,
		ascent = f32(ascent) * scale,
		line_height = f32(ascent - descent + line_gap) * scale,
	}
}

stb_measure_glyph :: proc(
	codepoint: rune,
	font_id: u16,
	font_size: f32,
	user_data: rawptr,
) -> ui.Glyph_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info

	scale := stbtt.ScaleForPixelHeight(font_info, font_size)

	advance_width, left_side_bearing: i32
	stbtt.GetCodepointHMetrics(font_info, codepoint, &advance_width, &left_side_bearing)

	x0, y0, x1, y1: i32

	return ui.Glyph_Metrics {
		advance_width = f32(advance_width) * scale,
		left_bearing = f32(left_side_bearing) * scale,
		width = f32(x1 - x0),
		height = f32(y1 - y0),
	}
}

stb_get_font_metrics :: proc(font_id: u16, font_size: f32, user_data: rawptr) -> ui.Font_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info
	scale := stbtt.ScaleForPixelHeight(font_info, font_size)
	ascent, descent, line_gap: i32
	stbtt.GetFontVMetrics(font_info, &ascent, &descent, &line_gap)

	return ui.Font_Metrics {
		size = font_size,
		line_height = f32(ascent - descent + line_gap) * scale,
		ascent = f32(ascent) * scale,
		descent = f32(descent) * scale,
	}
}
