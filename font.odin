package main

import "core:log"
import "core:mem"
import "core:os"

import sdl "vendor:sdl2"
import stbtt "vendor:stb/truetype"

Font_Glyph_Data :: struct {
	x0, y0, x1, y1: i32,
}

// TODO(Thomas): Ideally we'd like this to be rendering backend agnostic, but
// we'll just use sdl.Texture for now.
Font_Glyph_Atlas :: struct {
	font_info:   stbtt.fontinfo,
	font_data:   []u8,
	pack_ctx:    stbtt.pack_context,
	packed_char: []stbtt.packedchar,
	bitmap:      []u8,
	texture:     ^sdl.Texture,
	glyph_cache: map[rune]Font_Glyph_Data,
}

init_font_glyph_atlas :: proc(
	atlas: ^Font_Glyph_Atlas,
	path: string,
	allocator: mem.Allocator,
) -> bool {

	font_info := stbtt.fontinfo{}
	font_data, font_ok := os.read_entire_file_from_filename(path)
	if !font_ok {
		log.error("Failed to load font file")
		return false
	}
	atlas.font_data = font_data

	// Initialize font
	if !stbtt.InitFont(&font_info, raw_data(font_data), 0) {
		log.error("Failed to initialize font")
		return false
	}

	atlas.font_info = font_info

	atlas.pack_ctx = stbtt.pack_context{}
	atlas.packed_char = make([]stbtt.packedchar, 95)
	atlas.bitmap = make([]u8, 512 * 512, allocator)
	// TODO(Thomas): Make texture
	atlas.glyph_cache = make(map[rune]Font_Glyph_Data, allocator)

	// TODO(Thomas): What about passing in an alloc_context here?
	stbtt.PackBegin(&atlas.pack_ctx, raw_data(atlas.bitmap), 512, 512, 0, 1, nil)

	stbtt.PackFontRange(
		&atlas.pack_ctx,
		raw_data(atlas.font_data),
		0,
		12,
		32,
		95,
		raw_data(atlas.packed_char),
	)

	stbtt.PackEnd(&atlas.pack_ctx)

	for b in atlas.bitmap {
		if b != 0 {
			log.info("b: ", rune(b))
		}
	}

	return true
}

deinit_font_glyph_atlas :: proc(atlas: ^Font_Glyph_Atlas) {
}
