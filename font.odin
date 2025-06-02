package main
import sdl "vendor:sdl2"

Font_Glyph_Data :: struct {
}

// TODO(Thomas): Ideally we'd like this to be rendering backend agnostic, but
// we'll just use sdl.Texture for now.
Font_Glyph_Atlas :: struct {
	texture: ^sdl.Texture,
}
