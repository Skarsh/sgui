package backend

import "core:log"
import "core:mem"

import sdl "vendor:sdl2"

import ui "../ui"

Renderer_Type :: enum {
	OpenGL,
}

Render_Data :: union {
	OpenGL_Render_Data,
}

Render_Context :: struct {
	window:        Window,
	renderer_type: Renderer_Type,
	render_data:   Render_Data,
	allocator:     mem.Allocator,
}

init_render_ctx :: proc(
	ctx: ^Render_Context,
	window: Window,
	width, height: i32,
	stb_font_ctx: STB_Font_Context,
	font_size: f32,
	allocator := context.allocator,
	renderer_type: Renderer_Type,
) -> bool {

	win := window.handle
	ctx.window = window
	ctx.allocator = allocator
	ctx.renderer_type = renderer_type

	ok := false
	switch renderer_type {
	case .OpenGL:
		ok = init_opengl(&ctx.render_data, win, width, height, stb_font_ctx, font_size, allocator)
	}

	// TODO(Thomas): More details about which backend etc?
	if !ok {
		log.error("Failed to init renderer")
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

init_resources :: proc(ctx: ^Render_Context) -> bool {
	ok := false
	switch ctx.renderer_type {
	case .OpenGL:
		ok = opengl_init_resources(&ctx.render_data.(OpenGL_Render_Data))
	}
	return ok
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
	win := render_ctx.window.handle
	switch render_ctx.renderer_type {

	case .OpenGL:
		opengl_render_end(win, &render_ctx.render_data.(OpenGL_Render_Data), command_queue)
	}

	// TODO(Thomas) We're using SDL windowing for both right now, but
	// this should not be sdl specific later
	sdl.GL_SwapWindow(win)
}
