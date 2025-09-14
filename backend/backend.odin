package backend

import "core:container/queue"
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
	window_width, window_height: i32,
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
		window_width,
		window_height,
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

// TODO(Thomas): Putting process events here to make it easy to
// call resize procedures for the rendering. This does break
// the intended setup with all of the event stuff living inside IO though.
// TODO(Thomas): We should use our own Event type here instead of being
// reliant on SDL.
process_events :: proc(backend_ctx: ^Context, ctx: ^ui.Context) {
	io := &backend_ctx.io
	for {
		event, ok := queue.pop_front_safe(&io.input_queue)
		if !ok {
			break
		}

		#partial switch event.type {
		case .MOUSEMOTION:
			ui.handle_mouse_move(ctx, event.motion.x, event.motion.y)
		case .MOUSEBUTTONDOWN:
			btn: ui.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			ui.handle_mouse_down(ctx, event.motion.x, event.motion.y, btn)
		case .MOUSEBUTTONUP:
			btn: ui.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			ui.handle_mouse_up(ctx, event.motion.x, event.motion.y, btn)
		case .KEYUP:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_up(ctx, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(ctx, keymod)
		case .KEYDOWN:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_down(ctx, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(ctx, keymod)
		case .WINDOWEVENT:
			#partial switch event.window.event {
			case .SIZE_CHANGED:
				x := event.window.data1
				y := event.window.data2
				ctx.window_size.x = x
				ctx.window_size.y = y
				render_resize(&backend_ctx.render_ctx, x, y)
			}
		}
	}
	free_all(io.allocator)
}
