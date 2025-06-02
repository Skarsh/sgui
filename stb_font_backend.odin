package main

import "core:log"
import "core:os"

import stbtt "vendor:stb/truetype"

import ui "ui"

Font_Info :: stbtt.fontinfo

init_stb_font_ctx :: proc(ctx: ^STB_Font_Context, path: string) -> bool {
	font_data, font_ok := os.read_entire_file_from_filename(path)
	if !font_ok {
		log.error("Failed to load font file")
		return false
	}
	ctx.font_data = font_data

	// Initialize font
	if !stbtt.InitFont(ctx.font_info, raw_data(font_data), 0) {
		log.error("Failed to initialize font")
		return false
	}

	return true
}

deinit_stb_font_ctx :: proc(ctx: ^STB_Font_Context) {
	delete(ctx.font_data)
}

STB_Font_Context :: struct {
	font_info: ^stbtt.fontinfo,
	font_data: []byte,
}

stb_measure_text :: proc(
	text: string,
	font_id: u16,
	font_size: f32,
	user_data: rawptr,
) -> ui.Text_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info

	return ui.Text_Metrics{}
}

stb_measure_glyph :: proc(
	codepoint: rune,
	font_id: u16,
	font_size: f32,
	user_data: rawptr,
) -> ui.Glyph_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info

	return ui.Glyph_Metrics{}
}

stb_get_font_metrics :: proc(font_id: u16, font_size: f32, user_data: rawptr) -> ui.Font_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_info := ctx.font_info

	return ui.Font_Metrics{}
}
