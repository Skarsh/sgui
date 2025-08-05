package backend

import "core:log"
import "core:strings"

import sdl "vendor:sdl2"

import ui "../ui"

Window :: union {
	^sdl.Window,
}

Render_Context :: struct {}

init_render_ctx :: proc(
	ctx: ^Render_Context,
	window: Window,
	allocator := context.allocator,
) -> bool {

	return true
}

init_resources :: proc(ctx: ^Render_Context, paths: []string) {}

render_begin :: proc(render_ctx: ^Render_Context) {}

// TODO(Thomas): The command_stack could just be a member of render_ctx instead??
render_end :: proc(
	render_ctx: ^Render_Context,
	command_stack: ^ui.Stack(ui.Command, ui.COMMAND_STACK_SIZE),
) {}
