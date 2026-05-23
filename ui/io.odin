package ui

import "core:mem"

import "../base"
import textpkg "../text"

Text_Input_State :: struct {
	state:             textpkg.Text_Edit_State,
	caret_blink_timer: f32,
}

Io :: struct {
	// input is owned by app
	input:             ^base.Input,
	// text_measurement is owned by app
	text_measurement:  ^textpkg.Text_Measurement,
	text_input_states: map[UI_Key]Text_Input_State,
}

init_io :: proc(io: ^Io, allocator: mem.Allocator) {
	io.text_input_states = make(map[UI_Key]Text_Input_State, allocator)
}

deinit_io :: proc(io: ^Io) {
	for key in io.text_input_states {
		state := &io.text_input_states[key]
		textpkg.text_buffer_deinit(&state.state.buffer)
	}
	delete(io.text_input_states)
}
