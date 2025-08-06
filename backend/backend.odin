package backend

import "core:log"
import "core:mem"

import sdl "vendor:sdl2"

import ui "../ui"

Context :: struct {
	stb_font_ctx: STB_Font_Context,
	render_ctx:   Render_Context,
	io:           Io,
}

init_ctx :: proc(
	ctx: ^Context,
	ui_ctx: ^ui.Context,
	window: ^sdl.Window,
	texture_paths: []string,
	font_size: f32,
	allocator: mem.Allocator,
	io_allocator: mem.Allocator,
) -> bool {

	font_info := new(Font_Info, allocator)
	stb_font_ctx := STB_Font_Context {
		font_info = font_info,
	}

	if !init_stb_font_ctx(&stb_font_ctx, "data/fonts/font.ttf", font_size) {
		log.error("failed to init stb_font")
		return false
	}

	ctx.stb_font_ctx = stb_font_ctx
	ui.set_text_measurement_callbacks(
		ui_ctx,
		stb_measure_text,
		stb_measure_glyph,
		&ctx.stb_font_ctx,
	)

	render_ctx := Render_Context{}
	render_ctx_ok := init_render_ctx(
		&render_ctx,
		window,
		stb_font_ctx,
		font_size,
		allocator,
		//.SDL,
		.OpenGL,
		texture_paths,
	)
	if !render_ctx_ok {
		log.error("failed to init render context")
		return false
	}
	init_resources(&render_ctx, texture_paths)
	ctx.render_ctx = render_ctx

	io := Io{}
	init_io(&io, io_allocator)
	ctx.io = io

	return true
}

deinit :: proc(ctx: ^Context) {
	deinit_stb_font_ctx(&ctx.stb_font_ctx)
	deinit_render_ctx(&ctx.render_ctx)
}
