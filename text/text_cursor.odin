package text

import "core:unicode/utf8"

import "../base"

// The idea here is to provide an abstraction on top of Text_Buffer and string for
// text selection / cursor movement. For text buffer this will call the proper
// text_edit procedures, for editiing commands, and for string it will do non-edit
// text selection / cursor commands.
// If possible it would be nice to not have 2 separate command types, e.g. Text_Edit_Cmd
// and Text_Cursor_Cmd, but one unified one, where edit commands (insert, delete) become no-ops in
// the string (non-edit) cases.


Text_Source :: union {
	Text_Buffer,
	string,
}

// TODO(Thomas): Better name??
Text_Read_Only_State :: struct {
	text:      string,
	selection: Selection,
}

// TODO(Thomas): Better name??
Text_State :: union {
	^Text_Edit_State,
	^Text_Read_Only_State,
}

Cursor_Move :: struct {
	translation: Translation,
	select:      bool,
}

Cursor_Set_Caret :: struct {
	byte_pos: int,
	extend:   bool,
}

Cursor_Insert :: struct {
	text: string,
}

Cursor_Delete :: struct {
	translation: Translation,
}

Cursor_Select_All :: struct {}

Text_Cursor_Cmd :: union {
	Cursor_Move,
	Cursor_Set_Caret,
	Cursor_Insert,
	Cursor_Delete,
	Cursor_Select_All,
}

Clipboard_Command :: enum {
	None,
	Copy,
	Paste,
	Cut,
}

// TODO(Thomas): Error handling
text_cursor_handle_keys :: proc(
	state: Text_State,
	keys: base.Key_Set,
	keymod: base.Keymod_Set = base.KMOD_NONE,
) -> (
	clipboard_command: Clipboard_Command,
) {
	ctrl_down := base.is_ctrl_down(keymod)

	for key in keys {
		if cmd, ok := text_cursor_translate_key(key, keymod); ok {
			text_cursor_apply(state, cmd)
		} else if ctrl_down {

			// The rest are clipboard and undo/redo, still returned outward via the enum.
			#partial switch key {
			case .C:
				clipboard_command = .Copy
			case .V:
				clipboard_command = .Paste
			case .X:
				clipboard_command = .Cut
			case .Y:
			// TODO(Thomas): Redo
			case .Z:
			// TODO(Thomas): Undo
			}
		}
	}

	return
}

text_cursor_apply :: proc(state: Text_State, cmd: Text_Cursor_Cmd) {
	switch v in cmd {
	case Cursor_Move:
		text_cursor_move(state, v)
	case Cursor_Set_Caret:
		text_cursor_set_caret(state, v)
	case Cursor_Insert:
		text_cursor_insert(state, v)
	case Cursor_Delete:
		text_cursor_delete(state, v)
	case Cursor_Select_All:
		text_cursor_select_all(state, v)
	}
}

@(private)
text_cursor_translate_key :: proc(
	key: base.Key,
	keymod: base.Keymod_Set,
) -> (
	cmd: Text_Cursor_Cmd,
	ok: bool,
) {
	shift_down := base.is_shift_down(keymod)
	ctrl_down := base.is_ctrl_down(keymod)
	word_mod_down := keymod_has_word_move_mod(keymod)
	line_mod_down := keymod_has_line_move_mod(keymod)

	#partial switch key {
	case .A:
		if ctrl_down {
			return Cursor_Select_All{}, true
		}
	case .Left, .Right:
		translation := translation_for_horizontal_key(key, word_mod_down, line_mod_down)
		return Cursor_Move{translation = translation, select = shift_down}, true
	case .Home:
		return Cursor_Move{translation = .Start, select = shift_down}, true
	case .End:
		return Cursor_Move{translation = .End, select = shift_down}, true
	case .Backspace:
		translation: Translation = .Left
		if word_mod_down {
			translation = .Prev_Word
		}
		return Cursor_Delete{translation = translation}, true
	case .Delete:
		translation: Translation = .Right
		if word_mod_down {
			translation = .Next_Word
		}
		return Cursor_Delete{translation = translation}, true
	case .Tab:
		return Cursor_Insert{text = "\t"}, true
	}

	return nil, false
}

// TODO(Thomas): I don't really like that this is calls apply_move_or_select here,
// I think this should just call a text_edit_move() procedure.
// Will do it like this until we have verified that it behaves the same as before.
text_cursor_move :: proc(state: Text_State, cmd: Cursor_Move) {
	switch v in state {
	case ^Text_Edit_State:
		apply_move_or_select(v, cmd.translation, cmd.select)
	case ^Text_Read_Only_State:
		// TODO(Thomas): Implement this!
		unreachable()
	}
}

// TODO(Thomas): Should be possible to have a unified way of doing this,
// preventing the need for a switch? That will probably need a common type
// wrapping Selection and Text_Buffer / string? Not sure if worth.
// TODO(Thomas): If not able to unify, this should call a text_edit_set_caret procedure isntead
// of calling set_caret direclty here. This is only until we have verified
// that it behaves the same as before.
text_cursor_set_caret :: proc(state: Text_State, cmd: Cursor_Set_Caret) {
	switch v in state {
	case ^Text_Edit_State:
		if cmd.extend {
			set_active(v, cmd.byte_pos)
		} else {
			set_caret(v, cmd.byte_pos)
		}
	case ^Text_Read_Only_State:
		// TODO(Thomas): Implement this!
		unreachable()
	}
}

text_cursor_insert :: proc(state: Text_State, cmd: Cursor_Insert) {
	switch v in state {
	case ^Text_Edit_State:
		// TODO(Thomas): Handle error
		_ = text_edit_insert(v, cmd.text)
	case ^Text_Read_Only_State:
		// TODO(Thomas): Remove the unreachable when time is ready, this should just be a no-op
		// since its the read-only case.
		unreachable()
	}
}

text_cursor_delete :: proc(state: Text_State, cmd: Cursor_Delete) {
	switch v in state {
	case ^Text_Edit_State:
		text_edit_delete_to(v, cmd.translation)
	case ^Text_Read_Only_State:
		// TODO(Thomas): Remove the unreachable when time is ready, this should just be a no-op
		// since its the read-only case.
		unreachable()
	}
}

// TODO(Thomas): Should be possible to have a unified way of doing this,
// preventing the need for a switch? That will probably need a common type
// wrapping Selection and Text_Buffer / string? Not sure if worth.
// TODO(Thomas): If not able to unify, this should call a text_edit_select_all procedure.
text_cursor_select_all :: proc(state: Text_State, cmd: Cursor_Select_All) {
	switch v in state {
	case ^Text_Edit_State:
		v.selection.anchor = 0
		v.selection.active = text_buffer_byte_length(v.buffer)
	case ^Text_Read_Only_State:
		// TODO(Thomas): Implement this!
		unreachable()
	}
}

@(private)
@(require_results)
text_cursor_get_prev_rune :: proc(source: Text_Source, byte_idx: int) -> (rune, int) {
	r: rune = utf8.RUNE_ERROR
	width: int = 0

	switch v in source {
	case Text_Buffer:
		r, width = get_prev_rune(v, byte_idx)
	case string:
		r, width = utf8.decode_rune_in_string(v[:byte_idx])
	}

	return r, width
}

@(private)
@(require_results)
text_cursor_peek_rune_at_byte_offset :: proc(source: Text_Source, byte_idx: int) -> (rune, int) {
	r: rune = utf8.RUNE_ERROR
	width: int = 0

	switch v in source {
	case Text_Buffer:
		r, width = peek_rune_at_byte_offset(v, byte_idx)
	case string:
		r, width = utf8.decode_rune_in_string(v[byte_idx:])
	}

	return r, width
}

@(private)
@(require_results)
text_cursor_prev_word_byte_pos :: proc(source: Text_Source, pos: int) -> int {
	switch v in source {
	case Text_Buffer:
		return prev_word_byte_pos(v, pos)
	case string:
		byte_idx := clamp(pos, 0, len(v))
		for byte_idx > 0 && is_space(v[byte_idx - 1]) {
			byte_idx -= 1
		}
		for byte_idx > 0 && !is_space(v[byte_idx - 1]) {
			byte_idx -= 1
		}
		return byte_idx
	}
	return 0
}

@(private)
@(require_results)
text_cursor_next_word_byte_pos :: proc(source: Text_Source, pos: int) -> int {
	switch v in source {
	case Text_Buffer:
		return next_word_byte_pos(v, pos)
	case string:
		byte_len := len(v)
		byte_idx := clamp(pos, 0, byte_len)
		for byte_idx < byte_len && !is_space(v[byte_idx]) {
			byte_idx += 1
		}
		for byte_idx < byte_len && is_space(v[byte_idx]) {
			byte_idx += 1
		}
		return byte_idx
	}
	return 0
}
