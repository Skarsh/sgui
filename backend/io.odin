package backend

import "core:log"

import "../base"

// TODO(Thomas): Clean up when done with converting to nanos
Frame_Time :: struct {
	initial_counter: u64,
	counter:         u64,
	frequency:       u64,
	last:            u64,
	now:             u64,
	dt:              f32,
	dt_nanos:        u64,
	prev_total_ns:   u64,
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
		initial_counter = initial_counter,
		frequency       = frequency,
		last            = initial_counter,
		now             = initial_counter,
		dt              = 0,
	}

	io.platform_api = platform_api
	io.input = input
	io.window_size = window_size
	io.app_callbacks = app_callbacks

	return true
}

// Returns nanoseconds since the previous call.
//
// Converting only the ticks of each frame would lose the rounded off part every frame.
// So we convert the total since initial_counter and subtract the previous total.
// Caller must add the result to prev_total_ns before the next call.
//
// We split into seconds and remainder to avoid overflow.
//
// Example
// freq = 3
// initial_counter = 0
// one tick = 333_333_333.33... ns
//
// Total for each counter value:
//
//   now_counter | end | end_seconds | end_remainder | end_nanos
//   ------------+-----+-------------+---------------+--------------
//             1 |   1 |           0 |             1 |   333_333_333
//             2 |   2 |           0 |             2 |   666_666_666
//             3 |   3 |           1 |             0 | 1_000_000_000
//
// 3 frames of 1 tick:
//
//   now_counter | end_nanos     | prev_total_ns | dt_nanos
//   ------------+---------------+---------------+------------
//             1 |   333_333_333 |             0 | 333_333_333
//             2 |   666_666_666 |   333_333_333 | 333_333_333
//             3 | 1_000_000_000 |   666_666_666 | 333_333_334
//
// 1 frame of 2 ticks, then 1 frame of 1 tick:
//
//   now_counter | end_nanos     | prev_total_ns | dt_nanos
//   ------------+---------------+---------------+------------
//             2 |   666_666_666 |             0 | 666_666_666
//             3 | 1_000_000_000 |   666_666_666 | 333_333_334
//
// Both add up to 1_000_000_000. Converting only the ticks of each frame gives 999_999_999.
calc_nanos :: proc(now_counter: u64, prev_total_ns: u64, initial_counter: u64, freq: u64) -> u64 {
	end := now_counter - initial_counter
	end_seconds := end / freq
	end_remainder := end % freq

	end_nanos := (end_seconds * 1_000_000_000) + (end_remainder * 1_000_000_000) / freq

	dt_nanos := end_nanos - prev_total_ns

	return end_nanos - prev_total_ns
}

time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = io.platform_api.get_perf_counter()

	if io.frame_time.counter == 0 {
		io.frame_time.dt = 0
		io.frame_time.initial_counter = io.frame_time.now
	} else {
		io.frame_time.dt = f32(
			f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
		)

		log.info("dt: ", io.frame_time.dt)

		dt_nanos := calc_nanos(
			io.frame_time.now,
			io.frame_time.prev_total_ns,
			io.frame_time.initial_counter,
			io.frame_time.frequency,
		)
		io.frame_time.prev_total_ns += dt_nanos
		io.frame_time.dt_nanos = dt_nanos

		log.info("dt_nanos: ", io.frame_time.dt_nanos)
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
		base.set_keymods(input, e.mod)
		if e.down {
			base.handle_key_down(input, e.key)
		} else {
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
