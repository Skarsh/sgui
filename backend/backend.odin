package backend

import "core:log"
import "core:mem"

import "../base"
import textpkg "../text"

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
	destroy_gl_context:  proc(gl_context: rawptr),
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
		return {}, false
	}

	// SDL says attributes should be configured before creating window
	// https://wiki.libsdl.org/SDL2/SDL_GL_SetAttribute
	if !configure_opengl_window(window_api) {
		window_api.deinit()
		return {}, false
	}

	handle, ok := window_api.create_window(title, size)
	if !ok {
		log.error("Unable to create window")
		window_api.deinit()
		return {}, false
	}

	return Window{handle = handle, size = size}, true
}

deinit_window :: proc(window_api: Window_API, window: Window) {
	window_api.destroy_window(window.handle)
}

Context :: struct {
	window:     Window,
	window_api: Window_API,
	render_ctx: Render_Context,
	io:         Io,
}

init_ctx :: proc(
	ctx: ^Context,
	input: ^base.Input,
	text_measurement: ^textpkg.Text_Measurement,
	window_title: cstring,
	window_size: base.Vector2i32,
	font_configs: []base.Font_Config,
	platform_api: Platform_API,
	window_api: Window_API,
	app_callbacks: App_Callbacks,
	allocator: mem.Allocator,
) -> bool {

	if len(font_configs) == 0 {
		log.error("Provided zero font configuration, at least one is required")
		return false
	}

	window, window_ok := init_and_create_window(window_api, window_title, window_size)
	if !window_ok {
		return false
	}

	ctx.window = window
	ctx.window_api = window_api

	text_measurement.measure_text_proc = stb_measure_text
	text_measurement.measure_codepoint_proc = stb_measure_codepoint

	base.set_clipboard_text_procs(
		input,
		base.Clipboard_Text_Procs {
			platform_api.get_clipboard_text,
			platform_api.set_clipboard_text,
		},
	)

	render_ctx_ok := init_render_ctx(
		&ctx.render_ctx,
		&ctx.window,
		window_api,
		window_size,
		font_configs,
		.OpenGL,
		allocator,
	)
	if !render_ctx_ok {
		log.error("failed to init render context")
		deinit_window(window_api, window)
		window_api.deinit()
		ctx^ = {}
		return false
	}

	// This happens after render_ctx is initialized so we know everything is good
	for &desc, i in ctx.render_ctx.font_atlas.font_descs {
		font_configs[i].user_data = &desc.font_ctx
	}

	io := Io{}
	init_io(&io, platform_api, &ctx.window.size, input, app_callbacks)
	ctx.io = io

	return true
}

deinit :: proc(ctx: ^Context) {
	deinit_render_ctx(&ctx.render_ctx)
	ctx.window_api.destroy_gl_context(ctx.window.gl_context)
	deinit_window(ctx.window_api, ctx.window)
	ctx.window_api.deinit()
}

process :: proc(backend_ctx: ^Context) {
	io := &backend_ctx.io
	process_events(io)
	render_resize(&backend_ctx.render_ctx, backend_ctx.window.size.x, backend_ctx.window.size.y)
}
