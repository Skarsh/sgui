package backend

import "core:log"
import "core:strings"

import sdl "vendor:sdl2"

import ui "../ui"

Window :: union {
	^sdl.Window,
}

Render_Context :: struct {
	window:      Window,
	render_data: Render_Data,
}

init_render_ctx :: proc(
	ctx: ^Render_Context,
	window: Window,
	allocator := context.allocator,
) -> bool {

	win := window.(^sdl.Window)
	render_data, opengl_ok := init_opengl(win)
	assert(opengl_ok)
	if !opengl_ok {
		log.error("Failed to init opengl")
		return false
	}

	ctx.window = window
	ctx.render_data = render_data

	return true
}

deinit_render_ctx :: proc(ctx: ^Render_Context) {
	deinit_opengl(&ctx.render_data)
}

init_resources :: proc(ctx: ^Render_Context, paths: []string) {}

render_begin :: proc(render_ctx: ^Render_Context) {
	opengl_render_begin()
}

// TODO(Thomas): The command_stack could just be a member of render_ctx instead??
render_end :: proc(
	render_ctx: ^Render_Context,
	command_stack: ^ui.Stack(ui.Command, ui.COMMAND_STACK_SIZE),
) {
	win := render_ctx.window.(^sdl.Window)
	opengl_render_end(win, render_ctx.render_data)
	sdl.GL_SwapWindow(win)
}
