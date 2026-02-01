package backend

import "core:log"
import "core:mem"

import sdl "vendor:sdl2"

import "../base"
import ui "../ui"

// TODO(Thomas): This is hardcoded to use sdl now, this should support any windowing system
Window :: struct {
	handle: ^sdl.Window,
	size:   base.Vector2i32,
}

// TODO(Thomas): This is hardcoded to use sdl now, this should support any windowing system
init_and_create_window :: proc(title: string, size: base.Vector2i32) -> (Window, bool) {
	if sdl.Init(sdl.INIT_VIDEO) < 0 {
		log.error("Unable to init SDL: ", sdl.GetError())
		return Window{}, false
	}

	window := sdl.CreateWindow(
		"ImGUI",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		size.x,
		size.y,
		{.SHOWN, .RESIZABLE, .OPENGL},
	)

	if window == nil {
		log.error("Unable to create window: ", sdl.GetError())
		return Window{}, false
	}

	return Window{handle = window, size = size}, true
}

// TODO(Thomas): sdl.DestroyWindow() is hardcoded here now, this should be dependent on which windowing system
// backend is actually initalized with
deinit_window :: proc(window: Window) {
	sdl.DestroyWindow(window.handle)
}

Context :: struct {
	window:       Window,
	stb_font_ctx: STB_Font_Context,
	render_ctx:   Render_Context,
	io:           Io,
}

// TODO(Thomas): This shouldn't be aware of texture paths at all. That is app specific knowledge.
init_ctx :: proc(
	ctx: ^Context,
	ui_ctx: ^ui.Context,
	input: ^base.Input,
	window_title: string,
	window_size: base.Vector2i32,
	font_size: f32,
	platform_api: Platform_API,
	allocator: mem.Allocator,
	io_allocator: mem.Allocator,
) -> bool {

	window, window_ok := init_and_create_window(window_title, window_size)
	assert(window_ok)
	if !window_ok {
		log.error("Failed to init and create window")
		return false
	}
	ctx.window = window

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
		window_size,
		stb_font_ctx,
		font_size,
		allocator,
		//.SDL,
		.OpenGL,
	)
	if !render_ctx_ok {
		log.error("failed to init render context")
		return false
	}
	init_resources(&render_ctx)
	ctx.render_ctx = render_ctx

	io := Io{}
	init_io(&io, platform_api, &ctx.window.size, input, io_allocator)
	ctx.io = io

	return true
}

// TODO(Thomas): sdl.Quit() is hardcoded here now, this should be dependent on which windowing system
// backend is actually initalized with
deinit :: proc(ctx: ^Context) {
	deinit_stb_font_ctx(&ctx.stb_font_ctx)
	deinit_render_ctx(&ctx.render_ctx)
	sdl.Quit()
}

process :: proc(backend_ctx: ^Context) -> (should_close: bool) {
	io := &backend_ctx.io
	window := backend_ctx.window
	should_close = process_events(io)
	render_resize(&backend_ctx.render_ctx, window.size.x, window.size.y)
	return
}
