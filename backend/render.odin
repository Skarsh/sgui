package backend

import "core:log"
import "core:mem"

import sdl "vendor:sdl2"

import ui "../ui"

Window :: union {
	^sdl.Window,
}

Renderer_Type :: enum {
	SDL,
	OpenGL,
}

Render_Data :: union {
	SDL_Render_Data,
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
	stb_font_ctx: STB_Font_Context,
	font_size: f32,
	allocator := context.allocator,
	renderer_type: Renderer_Type,
	paths: []string,
) -> bool {

	win := window.(^sdl.Window)
	ctx.window = window
	ctx.allocator = allocator
	ctx.renderer_type = renderer_type

	ok := false
	switch renderer_type {
	case .SDL:
		ok = sdl_init_render(&ctx.render_data, win, stb_font_ctx, font_size, allocator)
	case .OpenGL:
		ok = init_opengl(&ctx.render_data, win, stb_font_ctx, font_size, allocator)
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
	case .SDL:
		sdl_deinit_render(&ctx.render_data.(SDL_Render_Data))
	case .OpenGL:
		deinit_opengl(&ctx.render_data.(OpenGL_Render_Data))
	}
}

init_resources :: proc(ctx: ^Render_Context, paths: []string) -> bool {
	ok := false
	switch ctx.renderer_type {
	case .SDL:
		ok = sdl_init_resources(&ctx.render_data.(SDL_Render_Data), paths)
	case .OpenGL:
		ok = opengl_init_resources(&ctx.render_data.(OpenGL_Render_Data), paths)
	}
	return ok
}

render_begin :: proc(render_ctx: ^Render_Context) {
	switch render_ctx.renderer_type {
	case .SDL:
		sdl_render_begin(&render_ctx.render_data.(SDL_Render_Data))
	case .OpenGL:
		opengl_render_begin(&render_ctx.render_data.(OpenGL_Render_Data))
	}
}

// TODO(Thomas): The command_stack could just be a member of render_ctx instead??
render_end :: proc(render_ctx: ^Render_Context, command_queue: []ui.Command) {
	win := render_ctx.window.(^sdl.Window)
	switch render_ctx.renderer_type {

	case .SDL:
		sdl_render_end(&render_ctx.render_data.(SDL_Render_Data), command_queue)
	case .OpenGL:
		opengl_render_end(win, &render_ctx.render_data.(OpenGL_Render_Data), command_queue)
	}

	// TODO(Thomas) We're using SDL windowing for both right now, but
	// this should not be sdl specific later
	sdl.GL_SwapWindow(win)
}
