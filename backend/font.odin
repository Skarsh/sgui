package backend

import "core:log"
import "core:mem"

import "../base"

import stbrp "vendor:stb/rect_pack"
import stbtt "vendor:stb/truetype"

// The atlas packs one contiguous codepoint range, so packed_chars[i] always
// holds the glyph for codepoint FIRST_PACKED_CODEPOINT + i. The range covers
// ASCII printables and the Latin-1 supplement (32 ..= 287).
FIRST_PACKED_CODEPOINT :: 32
NUM_PACKED_CODEPOINTS :: 256

// Ascent, descent and line_gap are stored
// as scaled to pixel values.
Font_Metrics :: struct {
	scale:    f32,
	ascent:   f32,
	descent:  f32,
	line_gap: f32,
}

Atlas_Glyph :: struct {
	// UV coordinates in the atlas texture
	u0, v0, u1, v1: f32,
	// Screen space positions
	x0, y0, x1, y1: f32,
	x_advance:      f32,
	// packed char idx
	pc_idx:         i32,
}

Bitmap :: struct {
	data:   []u8,
	width:  i32,
	height: i32,
}

Font_Desc :: struct {
	font_ctx:     STB_Font_Context,
	packed_chars: []stbtt.packedchar,
	pack_range:   stbtt.pack_range,
}

Font_Key :: struct {
	font_id:   int,
	codepoint: rune,
}

// TODO(Thomas): Ideally we'd want this to be library agnostic,
// but for now we're just using stb truetype here.
Font_Atlas :: struct {
	font_descs:  []Font_Desc,
	bitmap:      Bitmap,
	glyph_cache: map[Font_Key]Atlas_Glyph,
}

@(require_results)
init_font_desc :: proc(
	desc: ^Font_Desc,
	font_config: base.Font_Config,
	first_unicode_codepoint_in_range: i32,
	num_chars: i32,
	allocator: mem.Allocator,
) -> bool {

	if !init_stb_font_ctx(&desc.font_ctx, font_config.path, font_config.size) {
		return false
	}

	packed_chars := make([]stbtt.packedchar, num_chars, allocator)
	desc.packed_chars = packed_chars
	desc.pack_range = stbtt.pack_range {
		font_size                        = font_config.size,
		first_unicode_codepoint_in_range = first_unicode_codepoint_in_range,
		chardata_for_range               = raw_data(packed_chars),
		num_chars                        = num_chars,
	}

	return true
}

@(require_results)
init_font_atlas :: proc(
	atlas: ^Font_Atlas,
	font_configs: []base.Font_Config,
	atlas_width: i32,
	atlas_height: i32,
	allocator: mem.Allocator,
) -> bool {

	atlas.font_descs = make([]Font_Desc, len(font_configs), allocator)

	for &desc, i in atlas.font_descs {
		if !init_font_desc(
			&desc,
			font_configs[i],
			FIRST_PACKED_CODEPOINT,
			NUM_PACKED_CODEPOINTS,
			allocator,
		) {
			atlas^ = {}
			return false
		}
	}

	atlas.bitmap = Bitmap {
		data   = make([]u8, atlas_width * atlas_height, allocator),
		width  = atlas_width,
		height = atlas_height,
	}

	atlas.glyph_cache = make(map[Font_Key]Atlas_Glyph, allocator)
	pack_fonts(atlas)
	cache_packed_chars(atlas)

	return true
}

pack_fonts :: proc(atlas: ^Font_Atlas) {
	total_rects: int
	for desc in atlas.font_descs {
		total_rects += int(desc.pack_range.num_chars)
	}
	rects := make([]stbrp.Rect, total_rects, context.temp_allocator)
	defer free_all(context.temp_allocator)

	pack_ctx := stbtt.pack_context{}
	pack_begin_ok := stbtt.PackBegin(
		&pack_ctx,
		raw_data(atlas.bitmap.data),
		atlas.bitmap.width,
		atlas.bitmap.height,
		0,
		1,
		nil,
	)
	assert(bool(pack_begin_ok))

	stbtt.PackSetOversampling(&pack_ctx, 1, 1)

	offsets := make([dynamic]int, context.temp_allocator)
	offset: int
	for &desc in atlas.font_descs {
		n := stbtt.PackFontRangesGatherRects(
			&pack_ctx,
			&desc.font_ctx.font_info,
			&desc.pack_range,
			1,
			raw_data(rects[offset:]),
		)
		append(&offsets, offset)
		offset += int(n)
	}

	stbtt.PackFontRangesPackRects(&pack_ctx, raw_data(rects), i32(offset))

	for &desc, i in atlas.font_descs {
		stbtt.PackFontRangesRenderIntoRects(
			&pack_ctx,
			&desc.font_ctx.font_info,
			&desc.pack_range,
			1,
			raw_data(rects[offsets[i]:]),
		)
	}

	stbtt.PackEnd(&pack_ctx)
}


cache_packed_chars :: proc(atlas: ^Font_Atlas) {
	for &desc, font_idx in atlas.font_descs {
		// Cache ASCII printable characters
		// TODO(Thomas): Think about this
		// This is really all the codepoints in a certain range,
		// then offset for the start so that it's placed in the right
		// index in the packed chars. Pretty sure we can do this more robust
		for i in 0 ..< 95 {
			r := rune(32 + i)
			pc_idx := i32(int(r) - FIRST_PACKED_CODEPOINT)
			pc := desc.packed_chars[int(pc_idx)]

			glyph := Atlas_Glyph {
				u0        = f32(pc.x0) / f32(atlas.bitmap.width),
				v0        = f32(pc.y0) / f32(atlas.bitmap.height),
				u1        = f32(pc.x1) / f32(atlas.bitmap.width),
				v1        = f32(pc.y1) / f32(atlas.bitmap.height),
				x0        = pc.xoff,
				y0        = pc.yoff,
				x1        = pc.xoff2,
				y1        = pc.yoff2,
				x_advance = pc.xadvance,
				pc_idx    = pc_idx,
			}

			font_key := Font_Key {
				font_id   = font_idx,
				codepoint = r,
			}
			atlas.glyph_cache[font_key] = glyph
		}

		// Cache Latin-1 supplement characters
		// NOTE(Thomas): The range was packed starting at FIRST_PACKED_CODEPOINT, so
		// packed_chars[i] holds the glyph for codepoint FIRST_PACKED_CODEPOINT + i.
		for i in 0 ..< 96 {
			r := rune(160 + i)
			pc_idx := i32(int(r) - FIRST_PACKED_CODEPOINT)
			pc := desc.packed_chars[int(pc_idx)]

			glyph := Atlas_Glyph {
				u0        = f32(pc.x0) / f32(atlas.bitmap.width),
				v0        = f32(pc.y0) / f32(atlas.bitmap.height),
				u1        = f32(pc.x1) / f32(atlas.bitmap.width),
				v1        = f32(pc.y1) / f32(atlas.bitmap.height),
				x0        = pc.xoff,
				y0        = pc.yoff,
				x1        = pc.xoff2,
				y1        = pc.yoff2,
				x_advance = pc.xadvance,
				pc_idx    = pc_idx,
			}
			font_key := Font_Key {
				font_id   = font_idx,
				codepoint = r,
			}
			atlas.glyph_cache[font_key] = glyph
		}
	}
}

get_font_metrics :: proc(font_info: ^stbtt.fontinfo, font_size: f32) -> Font_Metrics {
	scale := stbtt.ScaleForPixelHeight(font_info, font_size)
	ascent, descent, line_gap: i32
	stbtt.GetFontVMetrics(font_info, &ascent, &descent, &line_gap)

	// Scale Font VMetrics by scale
	scaled_ascent := f32(ascent) * scale
	scaled_descent := f32(descent) * scale
	scaled_line_gap := f32(line_gap) * scale

	return Font_Metrics {
		scale = scale,
		ascent = scaled_ascent,
		descent = scaled_descent,
		line_gap = scaled_line_gap,
	}
}

deinit_font_atlas :: proc(atlas: ^Font_Atlas) {
	for &desc in atlas.font_descs {
		deinit_stb_font_ctx(&desc.font_ctx)
	}
}

// Query the atlas for a rune and get rendering information
get_glyph :: proc(atlas: ^Font_Atlas, font_id: int, codepoint: rune) -> (Atlas_Glyph, bool) {
	font_key := Font_Key{font_id, codepoint}
	glyph, glyph_ok := atlas.glyph_cache[font_key]
	if glyph_ok {
		return glyph, true
	}

	if codepoint >= 32 && codepoint <= 126 {
		log.warnf("Glyph should cached, but isn't: font_id: %d, codepoint: %v", font_id, codepoint)
		log.debug("Cache size: ", len(atlas.glyph_cache))
	}

	// Return '?' character as fallback
	fallback_font_key := Font_Key{0, '?'}
	if fallback, fallback_ok := atlas.glyph_cache[fallback_font_key]; fallback_ok {
		return fallback, false
	}

	return Atlas_Glyph{}, false
}

Glyph_Quad :: struct {
	x0, y0, s0, t0: f32, // top-left
	x1, y1, s1, t1: f32, // bottom-right
	x_advance:      f32,
}


// TODO(Thomas): Should be agnostic to font rasterization library, e.g. not
// depend on stb truetype
// TODO(Thomas): What to do about font_id being out of range?
get_glyph_quad :: proc(
	atlas: ^Font_Atlas,
	font_id: int,
	codepoint: rune,
	x, y: ^f32,
) -> (
	Glyph_Quad,
	bool,
) {
	assert(font_id >= 0 && font_id < len(atlas.font_descs), "font_id is out of range")
	glyph, found := get_glyph(atlas, font_id, codepoint)

	q: stbtt.aligned_quad

	desc := &atlas.font_descs[font_id]

	stbtt.GetPackedQuad(
		&desc.packed_chars[0],
		atlas.bitmap.width,
		atlas.bitmap.height,
		glyph.pc_idx,
		x,
		y,
		&q,
		true,
	)

	glyph_quad := Glyph_Quad{q.x0, q.y0, q.s0, q.t0, q.x1, q.y1, q.s1, q.t1, x^}

	return glyph_quad, found
}
