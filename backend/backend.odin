package backend

import "core:log"
import "core:mem"

import "../base"
import ui "../ui"

GL_Attribute :: enum {
	Context_Profile_Mask,
	Context_Major_Version,
	Context_Minor_Version,
}

GL_Profile :: enum i32 {
	Core          = 1,
	Compatibility = 2,
	ES            = 4,
}

GL_Set_Proc_Address_Type :: #type proc(p: rawptr, name: cstring)

Window_API :: struct {
	init:                proc() -> bool,
	deinit:              proc(),
	create_window:       proc(title: cstring, size: base.Vector2i32) -> (rawptr, bool),
	destroy_window:      proc(handle: rawptr),
	create_gl_context:   proc(handle: rawptr) -> (rawptr, bool),
	make_gl_current:     proc(handle: rawptr, gl_context: rawptr) -> bool,
	set_gl_attribute:    proc(attr: GL_Attribute, value: i32) -> bool,
	set_swap_interval:   proc(interval: i32) -> bool,
	swap_window:         proc(handle: rawptr),
	get_gl_proc_address: proc() -> GL_Set_Proc_Address_Type,
}

Window :: struct {
	handle:     rawptr,
	gl_context: rawptr,
	size:       base.Vector2i32,
}

init_and_create_window :: proc(
	window_api: Window_API,
	title: cstring,
	size: base.Vector2i32,
) -> (
	Window,
	bool,
) {
	if !window_api.init() {
		log.error("Unable to init window system")
		return Window{}, false
	}

	handle, ok := window_api.create_window(title, size)
	if !ok {
		log.error("Unable to create window")
		return Window{}, false
	}

	return Window{handle = handle, size = size}, true
}

deinit_window :: proc(window_api: Window_API, window: Window) {
	window_api.destroy_window(window.handle)
}

Context :: struct {
	window:       Window,
	window_api:   Window_API,
	stb_font_ctx: STB_Font_Context,
	render_ctx:   Render_Context,
	io:           Io,
}

// TODO(Thomas): This shouldn't be aware of texture paths at all. That is app specific knowledge.
init_ctx :: proc(
	ctx: ^Context,
	ui_ctx: ^ui.Context,
	input: ^base.Input,
	window_title: cstring,
	window_size: base.Vector2i32,
	font_size: f32,
	platform_api: Platform_API,
	window_api: Window_API,
	app_callbacks: App_Callbacks,
	allocator: mem.Allocator,
	io_allocator: mem.Allocator,
) -> bool {

	window, window_ok := init_and_create_window(window_api, window_title, window_size)
	assert(window_ok)
	if !window_ok {
		log.error("Failed to init and create window")
		return false
	}
	ctx.window = window
	ctx.window_api = window_api

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
		&ctx.window,
		window_api,
		window_size,
		stb_font_ctx,
		font_size,
		allocator,
		.OpenGL,
	)
	if !render_ctx_ok {
		log.error("failed to init render context")
		return false
	}
	init_resources(&render_ctx)
	ctx.render_ctx = render_ctx

	io := Io{}
	init_io(&io, platform_api, &ctx.window.size, input, app_callbacks, io_allocator)
	ctx.io = io

	return true
}

deinit :: proc(ctx: ^Context) {
	deinit_stb_font_ctx(&ctx.stb_font_ctx)
	deinit_render_ctx(&ctx.render_ctx)
	ctx.window_api.deinit()
}

process :: proc(backend_ctx: ^Context) {
	io := &backend_ctx.io
	window := backend_ctx.window
	process_events(io)
	render_resize(&backend_ctx.render_ctx, window.size.x, window.size.y)
}
