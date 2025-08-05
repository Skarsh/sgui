package backend

import "core:log"
import "core:strings"

import sdl "vendor:sdl2"

import ui "../ui"

Window :: union {
	^sdl.Window,
}

Render_Context :: struct {
	window: Window,
}

init_render_ctx :: proc(
	ctx: ^Render_Context,
	window: Window,
	allocator := context.allocator,
) -> bool {

	win := window.(^sdl.Window)
	init_opengl(win)
	ctx.window = window

	return true
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
	opengl_render_end(win)
}
