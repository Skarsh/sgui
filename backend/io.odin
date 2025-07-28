package backend

import sdl "vendor:sdl2"

Frame_Time :: struct {
	counter:   u64,
	frequency: u64,
	last:      u64,
	now:       u64,
	dt:        f32,
}

Io :: struct {
	frame_time: Frame_Time,
}

init_io :: proc(io: ^Io) {
	io.frame_time.frequency = sdl.GetPerformanceFrequency()
}

time :: proc(io: ^Io) {
	io.frame_time.last = io.frame_time.now
	io.frame_time.now = sdl.GetPerformanceCounter()
	io.frame_time.dt = f32(
		f32(io.frame_time.now - io.frame_time.last) / f32(io.frame_time.frequency),
	)

	io.frame_time.counter += 1
}
