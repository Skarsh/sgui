package backend

import "core:log"
import "core:mem"

import base "../base"
import ui "../ui"

Renderer_Type :: enum {
	OpenGL,
}

Render_Data :: union {
	OpenGL_Render_Data,
}

Render_Context :: struct {
	window:        ^Window,
	window_api:    Window_API,
	renderer_type: Renderer_Type,
	render_data:   Render_Data,
	font_atlas:    Font_Atlas,
	allocator:     mem.Allocator,
}

init_render_ctx :: proc(
	ctx: ^Render_Context,
	window: ^Window,
	window_api: Window_API,
	window_size: base.Vector2i32,
	font_configs: []base.Font_Config,
	renderer_type: Renderer_Type,
	allocator: mem.Allocator,
	scratch_allocator: mem.Allocator,
) -> bool {

	ctx.window = window
	ctx.window_api = window_api
	ctx.allocator = allocator
	ctx.renderer_type = renderer_type

	if !init_font_atlas(&ctx.font_atlas, font_configs, 1024, 1024, allocator) {
		log.error("Failed to init font atlas")
		ctx^ = {}
		return false
	}

	renderer_ok := init_opengl(
		&ctx.render_data,
		window,
		window_api,
		window_size,
		ctx.font_atlas,
		allocator,
		scratch_allocator,
	)

	if !renderer_ok {
		ctx^ = {}
		return false
	}

	return true
}

deinit_render_ctx :: proc(ctx: ^Render_Context) {
	switch ctx.renderer_type {
	case .OpenGL:
		deinit_opengl(&ctx.render_data.(OpenGL_Render_Data))
	}
}

render_resize :: proc(render_ctx: ^Render_Context, width, height: i32) {
	switch render_ctx.renderer_type {
	case .OpenGL:
		opengl_resize(&render_ctx.render_data.(OpenGL_Render_Data), width, height)
	}
}

render_begin :: proc(render_ctx: ^Render_Context) {
	switch render_ctx.renderer_type {
	case .OpenGL:
		opengl_render_begin(&render_ctx.render_data.(OpenGL_Render_Data))
	}
}

// TODO(Thomas): The command_stack could just be a member of render_ctx instead??
render_end :: proc(render_ctx: ^Render_Context, command_queue: []ui.Draw_Command) {
	switch render_ctx.renderer_type {
	case .OpenGL:
		opengl_render_end(&render_ctx.render_data.(OpenGL_Render_Data), command_queue)
	}

	render_ctx.window_api.swap_window(render_ctx.window.handle)
}
