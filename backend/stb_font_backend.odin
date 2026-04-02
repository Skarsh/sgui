package backend

import "core:log"
import "core:os"

import stbtt "vendor:stb/truetype"

import base "../base"
import textpkg "../text"

Font_Info :: stbtt.fontinfo

init_stb_font_ctx :: proc(ctx: ^STB_Font_Context, path: string, font_size: f32) -> bool {
	font_data, err := os.read_entire_file_from_path(path, context.allocator)

	if err != nil {
		log.error("Error when loading font file: ", err)
		return false
	}

	// Initialize font
	if !stbtt.InitFont(ctx.font_info, raw_data(font_data), 0) {
		log.error("Failed to initialize font")
		return false
	}

	ctx.font_data = font_data
	ctx.font_size = font_size
	ctx.font_metrics = get_font_metrics(ctx.font_info, font_size)

	return true
}

deinit_stb_font_ctx :: proc(ctx: ^STB_Font_Context) {
	delete(ctx.font_data)
}

STB_Font_Context :: struct {
	font_info:    ^stbtt.fontinfo,
	font_data:    []byte,
	font_size:    f32,
	font_metrics: Font_Metrics,
}

stb_measure_text :: proc(
	text: string,
	font_id: textpkg.Font_Handle,
	user_data: rawptr,
) -> textpkg.Text_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_metrics := ctx.font_metrics
	scale := font_metrics.scale
	ascent := font_metrics.ascent
	descent := font_metrics.descent
	line_gap := font_metrics.line_gap
	line_height := f32(ascent - descent + line_gap)

	// Measure space width once for tab character handling
	space_advance, space_bearing: i32
	stbtt.GetCodepointHMetrics(ctx.font_info, ' ', &space_advance, &space_bearing)
	space_width := f32(space_advance) * scale

	advance_width, left_side_bearing: i32
	width: f32
	for r in text {
		// Handle tab character with proper width
		if r == '\t' {
			width += base.calculate_tab_width(space_width)
			continue
		}

		stbtt.GetCodepointHMetrics(ctx.font_info, r, &advance_width, &left_side_bearing)
		width += f32(advance_width) * scale
	}

	return textpkg.Text_Metrics {
		width = width,
		ascent = ascent,
		descent = descent,
		line_height = line_height,
	}
}

stb_measure_codepoint :: proc(
	codepoint: rune,
	font_id: textpkg.Font_Handle,
	user_data: rawptr,
) -> textpkg.Codepoint_Metrics {
	ctx := cast(^STB_Font_Context)user_data
	font_metrics := ctx.font_metrics
	scale := font_metrics.scale

	advance_width, left_side_bearing: i32
	stbtt.GetCodepointHMetrics(ctx.font_info, codepoint, &advance_width, &left_side_bearing)
	width := f32(advance_width) * scale

	return textpkg.Codepoint_Metrics{width = f32(width), left_bearing = f32(left_side_bearing)}
}
