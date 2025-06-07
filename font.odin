package main

import "core:log"
import "core:mem"
import "core:unicode/utf8"

import sdl "vendor:sdl2"
import stbtt "vendor:stb/truetype"

// Ascent, descent and line_gap are stored
// as scaled to pixel values.
Font_Metrics :: struct {
	scale:    f32,
	ascent:   i32,
	descent:  i32,
	line_gap: i32,
}

Font_Data :: struct {
	// UV coordinates in the atlas texture
	u0, v0, u1, v1: f32,
	// Screen space positions
	x0, y0, x1, y1: f32,
	x_advance:      f32,
}

// TODO(Thomas): Ideally we'd like this to be rendering backend agnostic, but
// we'll just use sdl.Texture for now.
Font_Atlas :: struct {
	font_info:    ^stbtt.fontinfo,
	font_data:    []u8,
	pack_ctx:     stbtt.pack_context,
	packed_chars: []stbtt.packedchar,
	bitmap:       []u8,
	renderer:     ^sdl.Renderer,
	texture:      ^sdl.Texture,
	glyph_cache:  map[rune]Font_Data,
	atlas_width:  i32,
	atlas_height: i32,
	font_size:    f32,
	metrics:      Font_Metrics,
}

init_font_glyph_atlas :: proc(
	atlas: ^Font_Atlas,
	font_info: ^stbtt.fontinfo,
	font_data: []u8,
	path: string,
	font_size: f32,
	atlas_width: i32,
	atlas_height: i32,
	renderer: ^sdl.Renderer,
	allocator: mem.Allocator,
) -> bool {

	atlas.font_info = font_info
	atlas.font_data = font_data
	atlas.pack_ctx = stbtt.pack_context{}
	num_chars: i32 = 256
	atlas.packed_chars = make([]stbtt.packedchar, num_chars)
	atlas.renderer = renderer
	atlas.bitmap = make([]u8, atlas_width * atlas_height, allocator)

	atlas.glyph_cache = make(map[rune]Font_Data, allocator)

	// Set font dimensions
	atlas.atlas_width = atlas_width
	atlas.atlas_height = atlas_height
	atlas.font_size = font_size

	// Get font metrics
	atlas.metrics = get_font_metrics(atlas.font_info, atlas.font_size)

	// TODO(Thomas): What about passing in an alloc_context here?
	pack_ok := pack_font_glyphs(atlas, 32, num_chars, 0, 1, 2)
	if !pack_ok {
		log.error("Failed to pack font range")
		return false
	}

	//stbtt.PackEnd(&atlas.pack_ctx)
	// Create SDL texture from bitmap
	if !create_texture_from_bitmap(atlas) {
		log.error("Failed to create texture from bitmap")
		return false
	}

	// Pre-cache the packed characters
	cache_packed_chars(atlas)

	return true
}

get_font_metrics :: proc(font_info: ^stbtt.fontinfo, font_size: f32) -> Font_Metrics {
	scale := stbtt.ScaleForPixelHeight(font_info, font_size)
	ascent, descent, line_gap: i32
	stbtt.GetFontVMetrics(font_info, &ascent, &descent, &line_gap)

	// Scale Font VMetrics by scale
	ascent = i32(f32(ascent) * scale)
	descent = i32(f32(descent) * scale)
	line_gap = i32(f32(line_gap) * scale)

	return Font_Metrics{scale = scale, ascent = ascent, descent = descent, line_gap = line_gap}
}

pack_font_glyphs :: proc(
	atlas: ^Font_Atlas,
	first_codepoint: i32,
	num_chars: i32,
	stride_in_bytes: i32,
	padding: i32,
	oversampling: u32 = 2,
) -> bool {
	// Begin packing
	stbtt.PackBegin(
		&atlas.pack_ctx,
		raw_data(atlas.bitmap),
		atlas.atlas_width,
		atlas.atlas_height,
		stride_in_bytes, // stride_in_bytes (0 = packed)
		padding,
		nil, // alloc_context - TODO: Consider passing allocator context
	)

	// Set oversampling for better quality
	stbtt.PackSetOversampling(&atlas.pack_ctx, oversampling, oversampling)

	// Pack font range
	pack_result := stbtt.PackFontRange(
		&atlas.pack_ctx,
		raw_data(atlas.font_data),
		0, // font_index
		atlas.font_size,
		first_codepoint,
		num_chars,
		raw_data(atlas.packed_chars),
	)

	stbtt.PackEnd(&atlas.pack_ctx)

	return pack_result != 0
}

create_texture_from_bitmap :: proc(atlas: ^Font_Atlas) -> bool {
	// Convert single-channel bitmap to RGBA for SDL
	rgba_bitmap := make([]u8, atlas.atlas_width * atlas.atlas_height * 4, context.temp_allocator)

	// Convert grayscale to RGBA with white color and alpha from grayscale value
	for i in 0 ..< atlas.atlas_width * atlas.atlas_height {
		gray_value := atlas.bitmap[i]
		rgba_bitmap[i * 4 + 0] = 255 // R
		rgba_bitmap[i * 4 + 1] = 255 // G
		rgba_bitmap[i * 4 + 2] = 255 // B
		rgba_bitmap[i * 4 + 3] = gray_value // A
	}

	// Create SDL surface from RGBA data
	surface := sdl.CreateRGBSurfaceFrom(
		rawptr(raw_data(rgba_bitmap)),
		atlas.atlas_width,
		atlas.atlas_height,
		32, // Bits per pixel
		atlas.atlas_width * 4, // Pitch
		0x000000FF,
		0x0000FF00,
		0x00FF0000,
		0xFF000000, // RGBA masks
	)

	if surface == nil {
		log.error("Failed to create SDL surface")
		return false
	}

	// Create texture from surface
	atlas.texture = sdl.CreateTextureFromSurface(atlas.renderer, surface)
	if atlas.texture == nil {
		log.error("Failed to create texture from surface")
		return false
	}

	// Set blend mode for proper alpha blending
	sdl.SetTextureBlendMode(atlas.texture, .BLEND)

	return true
}

// We need to iterate over the packed chars and insert them 
// into the glyph cache
cache_packed_chars :: proc(atlas: ^Font_Atlas) {
	//atlas_width := atlas.atlas_width
	//atlas_height := atlas.atlas_height
	// Cache ASCII printable characters
	for i in 0 ..< 95 {
		r := rune(32 + i)
		pc := atlas.packed_chars[i]

		glyph := Font_Data {
			u0        = f32(pc.x0) / f32(atlas.atlas_width),
			v0        = f32(pc.y0) / f32(atlas.atlas_height),
			u1        = f32(pc.x1) / f32(atlas.atlas_width),
			v1        = f32(pc.y1) / f32(atlas.atlas_height),
			x0        = pc.xoff,
			y0        = pc.yoff,
			x1        = pc.xoff2,
			y1        = pc.yoff2,
			x_advance = pc.xadvance,
		}
		atlas.glyph_cache[r] = glyph
	}

	// Cache Latin-1 supplement characters
	for i in 0 ..< 96 {
		r := rune(160 + i)
		pc := atlas.packed_chars[95 + i]

		glyph := Font_Data {
			u0        = f32(pc.x0) / f32(atlas.atlas_width),
			v0        = f32(pc.y0) / f32(atlas.atlas_height),
			u1        = f32(pc.x1) / f32(atlas.atlas_width),
			v1        = f32(pc.y1) / f32(atlas.atlas_height),
			x0        = pc.xoff,
			y0        = pc.yoff,
			x1        = pc.xoff2,
			y1        = pc.yoff2,
			x_advance = pc.xadvance,
		}
		atlas.glyph_cache[r] = glyph
	}
}

// TODO(Thomas): Cleanup and free resources properly
deinit_font_glyph_atlas :: proc(atlas: ^Font_Atlas) {
}

// Query the atlas for a rune and get rendering information
get_glyph :: proc(atlas: ^Font_Atlas, codepoint: rune) -> (Font_Data, bool) {
	glyph, glyph_ok := atlas.glyph_cache[codepoint]
	if glyph_ok {
		return glyph, true
	}

	// Log what we're looking for and what we have
	if codepoint >= 32 && codepoint <= 126 {
		log.warn(
			"Glyph should be cached but isn't:",
			codepoint,
			"char: ",
			string(utf8.runes_to_string([]rune{codepoint})),
		)
		log.debug("Cache size: ", len(atlas.glyph_cache))
	}

	// Return '?' character as fallback
	if fallback, fallback_ok := atlas.glyph_cache['?']; fallback_ok {
		return fallback, false
	}

	// In practice this shouldn't really happen because '?' should always
	// be in the glyph_cache
	return Font_Data{}, false
}
