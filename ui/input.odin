package ui

import textedit "core:text/edit"

import base "../base"

Input :: struct {
	// Mouse
	mouse_pos:           base.Vector2i32,
	last_mouse_pos:      base.Vector2i32,
	mouse_delta:         base.Vector2i32,
	scroll_delta:        base.Vector2i32,
	mouse_down_bits:     base.Mouse_Set,
	mouse_pressed_bits:  base.Mouse_Set,
	mouse_released_bits: base.Mouse_Set,
	// Keys
	key_down_bits:       base.Key_Set,
	key_pressed_bits:    base.Key_Set,
	keymod_down_bits:    base.Keymod_Set,
}

handle_mouse_move :: proc(ctx: ^Context, x, y: i32) {
	ctx.input.mouse_pos = {x, y}
}

handle_mouse_down :: proc(ctx: ^Context, x, y: i32, btn: base.Mouse) {
	handle_mouse_move(ctx, x, y)
	ctx.input.mouse_down_bits += {btn}
	ctx.input.mouse_pressed_bits += {btn}
}

handle_scroll :: proc(ctx: ^Context, x, y: i32) {
	ctx.input.scroll_delta.x += x
	ctx.input.scroll_delta.y += y
}

handle_mouse_up :: proc(ctx: ^Context, x, y: i32, btn: base.Mouse) {
	handle_mouse_move(ctx, x, y)
	ctx.input.mouse_down_bits -= {btn}
	ctx.input.mouse_released_bits += {btn}
}

handle_keymod_down :: proc(ctx: ^Context, keymod: base.Keymod_Set) {
	ctx.input.keymod_down_bits = keymod
}

handle_keymod_up :: proc(ctx: ^Context, keymod: base.Keymod_Set) {
	ctx.input.keymod_down_bits = keymod
}

handle_key_down :: proc(ctx: ^Context, key: base.Key) {
	ctx.input.key_pressed_bits += {key}
	ctx.input.key_down_bits += {key}
}

handle_key_up :: proc(ctx: ^Context, key: base.Key) {
	ctx.input.key_down_bits -= {key}
}

// TODO(Thomas): Should we really do the textedit input here???
// I do think I would prefer that this doesn't know details about
// how text are inputted into the textedit etc.
handle_text :: proc(ctx: ^Context, text: string) {
	if ctx.active_element != nil {
		key := ui_key_hash(ctx.active_element.id_string)
		if state, ok := &ctx.text_input_states[key]; ok {
			textedit.input_text(&state.state, text)
		}
	}
}

is_mouse_down :: proc(ctx: Context, mouse: base.Mouse) -> bool {
	return mouse in ctx.input.mouse_down_bits
}

is_mouse_pressed :: proc(ctx: Context, mouse: base.Mouse) -> bool {
	return mouse in ctx.input.mouse_pressed_bits
}

is_mouse_released :: proc(ctx: Context, mouse: base.Mouse) -> bool {
	return mouse in ctx.input.mouse_released_bits
}

is_key_down :: proc(ctx: Context, key: base.Key) -> bool {
	return key in ctx.input.key_down_bits
}

is_key_pressed :: proc(ctx: Context, key: base.Key) -> bool {
	return key in ctx.input.key_pressed_bits
}

clear_input :: proc(ctx: ^Context) {
	ctx.input.key_pressed_bits = {}
	ctx.input.mouse_pressed_bits = {}
	ctx.input.mouse_released_bits = {}
	ctx.input.scroll_delta = {}
}
