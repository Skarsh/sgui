package backend

import "core:container/queue"
import "core:log"
import "core:mem"
import sdl "vendor:sdl2"

import "../base"

Frame_Time :: struct {
	counter:   u64,
	frequency: u64,
	last:      u64,
	now:       u64,
	dt:        f32,
}

// TODO(Thomas): The queue should hold our own Event type so we're not
// reliant on SDL
Io :: struct {
	allocator:   mem.Allocator,
	frame_time:  Frame_Time,
	input_queue: queue.Queue(sdl.Event),
	// input pointer is owned by backend context
	input:       ^base.Input,
	// window_size pointer is owned by backend context
	window_size: ^base.Vector2i32,
}

// TODO(Thomas): We should use our own GetPerformanceCounter wrapper procedure at least, so we're
// not reliant on SDL.
init_io :: proc(
	io: ^Io,
	window_size: ^base.Vector2i32,
	input: ^base.Input,
	allocator: mem.Allocator,
) -> bool {
	io.frame_time.frequency = sdl.GetPerformanceFrequency()
	io.allocator = allocator
	alloc_err := queue.init(&io.input_queue, 32, io.allocator)
	assert(alloc_err == .None)
	if alloc_err != .None {
		log.error("Failed to init input queue")
		return false
	}

	io.input = input
	io.window_size = window_size

	return true
}

// TODO(Thomas): We should use our own GetPerformanceCounter wrapper procedure at least, so we're
// not reliant on SDL.
time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = sdl.GetPerformanceCounter()
	io.frame_time.dt = f32(
		f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
	)

	io.frame_time.counter += 1
}

// TODO(Thomas): We should use our own GetPerformanceCounter wrapper procedure at least, so we're
// not reliant on SDL.
enqueue_sdl_event :: proc(io: ^Io, event: sdl.Event) {
	queue.push_back(&io.input_queue, event)
}


sdl_key_to_ui_key :: proc(sdl_key: sdl.Keycode) -> base.Key {
	key := base.Key.Unknown
	// TODO(Thomas): Complete more of this switch
	#partial switch sdl_key {
	case .ESCAPE:
		key = base.Key.Escape
	case .TAB:
		key = base.Key.Tab
	case .RETURN:
		key = base.Key.Return
	case .UP:
		key = base.Key.Up
	case .DOWN:
		key = base.Key.Down
	case .LEFT:
		key = base.Key.Left
	case .RIGHT:
		key = base.Key.Right
	case .LSHIFT:
		key = base.Key.Left_Shift
	case .RSHIFT:
		key = base.Key.Right_Shift
	case .BACKSPACE:
		key = base.Key.Backspace
	}
	return key
}

sdl_keymod_to_ui_keymod :: proc(sdl_key_mod: sdl.Keymod) -> base.Keymod_Set {
	key_mod := base.KMOD_NONE

	// TODO(Thomas): Do this for the complete set of modifiers
	if .LSHIFT in sdl_key_mod {
		key_mod = base.KMOD_LSHIFT
	} else if .RSHIFT in sdl_key_mod {
		key_mod = base.KMOD_RSHIFT
	} else if .LSHIFT in sdl_key_mod && .RSHIFT in sdl_key_mod {
		key_mod = base.KMOD_SHIFT
	}

	return key_mod
}

// TODO(Thomas): We should use our own Event type here instead of being
// reliant on SDL.
process_events :: proc(io: ^Io) {
	input := io.input
	for {
		event, ok := queue.pop_front_safe(&io.input_queue)
		if !ok {
			break
		}

		#partial switch event.type {
		case .MOUSEMOTION:
			base.handle_mouse_move(input, event.motion.x, event.motion.y)
		case .MOUSEBUTTONDOWN:
			btn: base.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			base.handle_mouse_down(input, event.motion.x, event.motion.y, btn)
		case .MOUSEBUTTONUP:
			btn: base.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			base.handle_mouse_up(input, event.motion.x, event.motion.y, btn)
		case .MOUSEWHEEL:
			base.handle_scroll(input, event.wheel.x, event.wheel.y)
		case .KEYUP:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			base.handle_key_up(input, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			base.handle_keymod_up(input, keymod)
		case .KEYDOWN:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			base.handle_key_down(input, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			base.handle_keymod_up(input, keymod)
		case .TEXTINPUT:
			text := string(cstring(&event.text.text[0]))
			handle_text_ok := base.handle_text(input, text)
			if !handle_text_ok {
				log.error("Failed to handle text: ", text)
			}
		case .WINDOWEVENT:
			#partial switch event.window.event {
			case .SIZE_CHANGED:
				x := event.window.data1
				y := event.window.data2
				io.window_size.x = x
				io.window_size.y = y
			}
		}
	}
	free_all(io.allocator)
}
