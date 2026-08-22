package backend

import "core:log"

import "../base"

Frame_Time :: struct {
	counter:   u64,
	frequency: u64,
	last:      u64,
	now:       u64,
	dt:        f32,
}

Platform_API :: struct {
	get_perf_counter:   proc() -> u64,
	get_perf_freq:      proc() -> u64,
	get_clipboard_text: base.Get_Clipboard_Text_Proc,
	set_clipboard_text: base.Set_Clipboard_Text_Proc,
	poll_events:        proc(
		user_data: rawptr,
		on_event: proc(user_data: rawptr, event: base.Event),
	),
}

assert_platform_api :: proc(platform_api: Platform_API) {
	assert(platform_api.get_perf_counter != nil)
	assert(platform_api.get_perf_freq != nil)
	assert(platform_api.get_clipboard_text != nil)
	assert(platform_api.set_clipboard_text != nil)
	assert(platform_api.poll_events != nil)
}

App_Callbacks :: struct {
	on_quit:      proc(user_data: rawptr),
	on_quit_data: rawptr,
}

Io :: struct {
	frame_time:    Frame_Time,
	platform_api:  Platform_API,
	app_callbacks: App_Callbacks,
	// input pointer is owned by backend context
	input:         ^base.Input,
	// window_size pointer is owned by backend context
	window_size:   ^base.Vector2i32,
}

init_io :: proc(
	io: ^Io,
	platform_api: Platform_API,
	window_size: ^base.Vector2i32,
	input: ^base.Input,
	app_callbacks: App_Callbacks,
) -> bool {
	assert_platform_api(platform_api)

	frequency := platform_api.get_perf_freq()
	assert(frequency > 0)

	initial_counter := platform_api.get_perf_counter()

	io.frame_time = Frame_Time {
		frequency = frequency,
		last      = initial_counter,
		now       = initial_counter,
		dt        = 0,
	}

	io.platform_api = platform_api
	io.input = input
	io.window_size = window_size
	io.app_callbacks = app_callbacks

	return true
}


time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = io.platform_api.get_perf_counter()

	if io.frame_time.counter == 0 {
		io.frame_time.dt = 0
	} else {
		io.frame_time.dt = f32(
			f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
		)
	}

	io.frame_time.counter += 1
}

apply_event :: proc(io: ^Io, event: base.Event) {
	input := io.input

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
			base.handle_key_down(input, e.key)
		} else {
			base.handle_keymod_up(input, e.mod)
			base.handle_key_up(input, e.key)
		}
	case base.Text_Input_Event:
		text := e.text
		if !base.handle_text(input, string(cstring(&text[0]))) {
			log.error("Failed to handle text")
		}
	case base.Window_Event:
		io.window_size.x = e.size_x
		io.window_size.y = e.size_y
	case base.Quit_Event:
		if io.app_callbacks.on_quit != nil {
			io.app_callbacks.on_quit(io.app_callbacks.on_quit_data)
		}
	}
}

_io_handle_event_callback :: proc(user_data: rawptr, event: base.Event) {
	apply_event((^Io)(user_data), event)
}

process_events :: proc(io: ^Io) {
	io.platform_api.poll_events(io, _io_handle_event_callback)
}
