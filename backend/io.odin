package backend

import "core:container/queue"
import "core:log"
import "core:mem"

import "../base"

Frame_Time :: struct {
	counter:   u64,
	frequency: u64,
	last:      u64,
	now:       u64,
	dt:        f32,
}

Platform_API :: struct {
	get_perf_counter: proc() -> u64,
	get_perf_freq:    proc() -> u64,
	poll_events:      proc(
		user_data: rawptr,
		on_event: proc(user_data: rawptr, event: base.Event),
	),
}

// TODO(Thomas): The queue should hold our own Event type so we're not
// reliant on SDL
Io :: struct {
	allocator:    mem.Allocator,
	frame_time:   Frame_Time,
	platform_api: Platform_API,
	//input_queue:  queue.Queue(sdl.Event),
	input_queue:  queue.Queue(base.Event),
	// input pointer is owned by backend context
	input:        ^base.Input,
	// window_size pointer is owned by backend context
	window_size:  ^base.Vector2i32,
}

init_io :: proc(
	io: ^Io,
	platform_api: Platform_API,
	window_size: ^base.Vector2i32,
	input: ^base.Input,
	allocator: mem.Allocator,
) -> bool {
	io.frame_time.frequency = platform_api.get_perf_freq()
	io.allocator = allocator
	alloc_err := queue.init(&io.input_queue, 32, io.allocator)
	assert(alloc_err == .None)
	if alloc_err != .None {
		log.error("Failed to init input queue")
		return false
	}

	io.platform_api = platform_api
	io.input = input
	io.window_size = window_size

	return true
}

_io_push_event_callback :: proc(user_data: rawptr, event: base.Event) {
	io := (^Io)(user_data)
	queue.push_back(&io.input_queue, event)
}

time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = io.platform_api.get_perf_counter()
	io.frame_time.dt = f32(
		f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
	)
	io.frame_time.counter += 1
}

process_events :: proc(io: ^Io) -> (should_quit: bool) {
	io.platform_api.poll_events(io, _io_push_event_callback)

	input := io.input

	for {
		event, ok := queue.pop_front_safe(&io.input_queue)
		if !ok {break}

		switch e in event {
		case base.Mouse_Motion_Event:
			base.handle_mouse_move(input, e.x, e.y)
		case base.Mouse_Button_Event:
			if e.down {
				base.handle_mouse_down(input, e.x, e.y, e.button)
			} else {
				base.handle_mouse_up(input, e.x, e.y, e.button)
			}
		case base.Mouse_Wheel_Event:
			base.handle_scroll(input, e.x, e.y)
		case base.Keyboard_Event:
			if e.down {
				base.handle_keymod_down(input, e.mod)
				base.handle_key_up(input, e.key)
			} else {
				base.handle_keymod_up(input, e.mod)
				base.handle_key_up(input, e.key)
			}
		case base.Text_Input_Event:
			// TODO(Thomas): HACK, can we do this another way?? Thinking about the copy
			text := e.text
			base.handle_text(input, text[:])
		case base.Window_Event:
			io.window_size.x = e.size_x
			io.window_size.y = e.size_y
		case base.Quit_Event:
			should_quit = true
			break
		}
	}
	free_all(io.allocator)
	return
}
