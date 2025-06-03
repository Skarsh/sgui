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
	font_info:    stbtt.fontinfo,
	font_data:    []u8,
	pack_ctx:     stbtt.pack_context,
	packed_chars: []stbtt.packedchar,
	bitmap:       []u8,
	texture:      ^sdl.Texture,
	glyph_cache:  map[rune]Font_Glyph_Data,
	font_size:    f32,
	atlas_width:  i32,
	atlas_height: i32,
}

init_font_glyph_atlas :: proc(
	atlas: ^Font_Glyph_Atlas,
	path: string,
	font_size: f32,
	atlas_width: i32,
	atlas_height: i32,
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
	atlas.packed_chars = make([]stbtt.packedchar, 95)
	atlas.bitmap = make([]u8, atlas_width * atlas_height, allocator)

	// TODO(Thomas): Make texture
	atlas.glyph_cache = make(map[rune]Font_Glyph_Data, allocator)

	// TODO(Thomas): What about passing in an alloc_context here?
	stbtt.PackBegin(&atlas.pack_ctx, raw_data(atlas.bitmap), atlas_width, atlas_height, 0, 1, nil)

	stbtt.PackFontRange(
		&atlas.pack_ctx,
		raw_data(atlas.font_data),
		0,
		font_size,
		32,
		95,
		raw_data(atlas.packed_chars),
	)

	stbtt.PackEnd(&atlas.pack_ctx)

	cache_packed_chars(atlas)

	return true
}

// We need to iterate over the packed chars and insert them 
// into the glyph cache
cache_packed_chars :: proc(atlas: ^Font_Glyph_Atlas) {
	for i in 0 ..< 95 {
		r := rune(32 + i)
		pc := atlas.packed_chars[i]
		log.info("r: ", r)
	}
}

deinit_font_glyph_atlas :: proc(atlas: ^Font_Glyph_Atlas) {
}
