package backend

import "core:container/queue"
import "core:log"
import "core:mem"
import sdl "vendor:sdl2"

import ui "../ui"

Frame_Time :: struct {
	counter:   u64,
	frequency: u64,
	last:      u64,
	now:       u64,
	dt:        f32,
}

Io :: struct {
	allocator:   mem.Allocator,
	frame_time:  Frame_Time,
	input_queue: queue.Queue(sdl.Event),
}

init_io :: proc(io: ^Io, allocator: mem.Allocator) -> bool {
	io.frame_time.frequency = sdl.GetPerformanceFrequency()
	io.allocator = allocator
	alloc_err := queue.init(&io.input_queue, 32, io.allocator)
	assert(alloc_err == .None)
	if alloc_err != .None {
		log.error("Failed to init input queue")
		return false
	}
	return true
}

time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = sdl.GetPerformanceCounter()
	io.frame_time.dt = f32(
		f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
	)

	io.frame_time.counter += 1
}

enqueue_sdl_event :: proc(io: ^Io, event: sdl.Event) {
	queue.push_back(&io.input_queue, event)
}

process_events :: proc(io: ^Io, ctx: ^ui.Context) {
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
				ctx.window_size.x = event.window.data1
				ctx.window_size.y = event.window.data2
			}
		}
	}
	free_all(io.allocator)
}

sdl_key_to_ui_key :: proc(sdl_key: sdl.Keycode) -> ui.Key {
	key := ui.Key.Unknown
	// TODO(Thomas): Complete more of this switch
	#partial switch sdl_key {
	case .ESCAPE:
		key = ui.Key.Escape
	case .TAB:
		key = ui.Key.Tab
	case .RETURN:
		key = ui.Key.Return
	case .UP:
		key = ui.Key.Up
	case .DOWN:
		key = ui.Key.Down
	case .LSHIFT:
		key = ui.Key.Left_Shift
	case .RSHIFT:
		key = ui.Key.Right_Shift
	case .BACKSPACE:
		key = ui.Key.Backspace
	}
	return key
}

sdl_keymod_to_ui_keymod :: proc(sdl_key_mod: sdl.Keymod) -> ui.Keymod_Set {
	key_mod := ui.KMOD_NONE

	// TODO(Thomas): Do this for the complete set of modifiers
	if .LSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_LSHIFT
	} else if .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_RSHIFT
	} else if .LSHIFT in sdl_key_mod && .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_SHIFT
	}

	return key_mod
}
