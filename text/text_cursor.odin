package text

// Based on this RXI article
// https://rxi.github.io/textbox_behaviour.html

import "core:mem"
import "core:unicode/utf8"

import "../base"

Translation :: enum {
	Left,
	Right,
	Next_Word,
	Prev_Word,
	Start,
	End,
}

// Byte indexes
Selection :: struct {
	active: int,
	anchor: int,
}

Text_Source :: union {
	Text_Buffer,
	string,
}


Text_Edit_State :: struct {
	buffer:  Text_Buffer,
	max_len: int,
}

text_edit_init :: proc(state: ^Text_Edit_State, buffer: Text_Buffer, max_len: int = max(int)) {
	state.buffer = buffer
	state.max_len = max_len
}

text_edit_deinit :: proc(state: ^Text_Edit_State) {
	text_buffer_deinit(&state.buffer)
}

Text_Read_Only_State :: struct {
	text: string,
}

// Text is owned by the caller, and it can be different every frame.
// This function makes sure that the string in the state points to the
// right one, and that the selection is clamped to the new string pointed to.
text_read_only_set_text :: proc(state: ^Text_State, text: string) {
	read_only, is_read_only := &state.variant.(Text_Read_Only_State)
	assert(is_read_only, "text_read_only_set_text requires a read only text state")

	read_only.text = text
	state.selection.active = clamp(state.selection.active, 0, len(text))
	state.selection.anchor = clamp(state.selection.anchor, 0, len(text))
}

Text_State :: struct {
	selection: Selection,
	variant:   union {
		Text_Edit_State,
		Text_Read_Only_State,
	},
}

deinit_text_state :: proc(state: ^Text_State) {
	switch &v in state.variant {
	case Text_Edit_State:
		text_edit_deinit(&v)

	case Text_Read_Only_State:
	// Nothing to free
	}
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

text_cursor_handle_keys :: proc(
	state: ^Text_State,
	keys: base.Key_Set,
	keymod: base.Keymod_Set = base.KMOD_NONE,
) -> (
	clipboard_command: Clipboard_Command,
	error: Text_Buffer_Error,
) {
	ctrl_down := base.is_ctrl_down(keymod)

	for key in keys {
		if cmd, ok := text_cursor_translate_key(key, keymod); ok {
			text_cursor_apply(state, cmd) or_return
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


text_cursor_move :: proc(state: ^Text_State, cmd: Cursor_Move) {
	target := text_cursor_translated_pos(state, cmd.translation, !cmd.select)
	if cmd.select {
		set_active(state, target)
	} else {
		set_caret(state, target)
	}
}

text_cursor_set_caret :: proc(state: ^Text_State, cmd: Cursor_Set_Caret) {
	if cmd.extend {
		set_active(state, cmd.byte_pos)
	} else {
		set_caret(state, cmd.byte_pos)
	}
}

@(require_results)
text_cursor_insert :: proc(state: ^Text_State, cmd: Cursor_Insert) -> Text_Buffer_Error {
	switch &v in state.variant {
	case Text_Edit_State:
		insert_at := state.selection.active
		if !is_selection_collapsed(state.selection) {
			start := selection_start(state.selection)
			end := selection_end(state.selection)
			text_buffer_delete_range(&v.buffer, start, end - start)
			insert_at = start
		}

		current_len := text_buffer_byte_length(v.buffer)
		if current_len + len(cmd.text) <= v.max_len {
			text_buffer_insert_at(&v.buffer, insert_at, cmd.text) or_return
			set_caret(state, insert_at + len(cmd.text))
		}
	case Text_Read_Only_State:
	// no-op
	}
	return nil
}

text_cursor_delete :: proc(state: ^Text_State, cmd: Cursor_Delete) {
	switch &v in state.variant {
	case Text_Edit_State:
		if is_selection_collapsed(state.selection) {
			text_cursor_move(state, Cursor_Move{translation = cmd.translation, select = true})
		}

		start := selection_start(state.selection)
		end := selection_end(state.selection)

		if start != end {
			text_buffer_delete_range(&v.buffer, start, end - start)
		}
		set_caret(state, start)
	case Text_Read_Only_State:
	// no-op
	}
}


selection_start :: proc(selection: Selection) -> int {
	return min(selection.active, selection.anchor)
}

selection_end :: proc(selection: Selection) -> int {
	return max(selection.active, selection.anchor)
}

@(require_results)
text_cursor_get_text :: proc(
	state: ^Text_State,
	allocator: mem.Allocator,
) -> (
	string,
	mem.Allocator_Error,
) {
	source, _ := text_state_parts(state)
	switch v in source {
	case Text_Buffer:
		return text_buffer_text(v, allocator)
	case string:
		return v, nil
	}

	return "", nil
}

@(require_results)
text_cursor_get_selection :: proc(state: ^Text_State) -> Selection {
	_, selection := text_state_parts(state)
	return selection^
}

@(private)
@(require_results)
text_cursor_apply :: proc(state: ^Text_State, cmd: Text_Cursor_Cmd) -> Text_Buffer_Error {
	switch v in cmd {
	case Cursor_Move:
		text_cursor_move(state, v)
	case Cursor_Set_Caret:
		text_cursor_set_caret(state, v)
	case Cursor_Insert:
		text_cursor_insert(state, v) or_return
	case Cursor_Delete:
		text_cursor_delete(state, v)
	case Cursor_Select_All:
		text_cursor_select_all(state, v)
	}
	return nil
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

@(private)
text_cursor_select_all :: proc(state: ^Text_State, cmd: Cursor_Select_All) {
	source, selection := text_state_parts(state)
	selection.anchor = 0
	selection.active = text_source_byte_length(source)
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
		r, width = utf8.decode_last_rune_in_string(v[:byte_idx])
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
	// For the text buffer case we need to check if the byte we're trying
	// to go backwards to is valid.
	// For the string case we assume that it is valid.
	switch v in source {
	case Text_Buffer:
		byte_idx := clamp(pos, 0, text_buffer_byte_length(v))

		for byte_idx > 0 {
			b, ok := text_buffer_get_byte_at(v, byte_idx - 1)
			if !ok {
				break
			}

			if !is_space(b) {
				break
			}

			byte_idx -= 1
		}

		for byte_idx > 0 {
			b, ok := text_buffer_get_byte_at(v, byte_idx - 1)
			if !ok {
				break
			}

			if is_space(b) {
				break
			}

			byte_idx -= 1
		}

		return byte_idx
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
	// For the text buffer case we need to check if the byte we're trying
	// to go to next is valid.
	// For the string case we assume that it is valid.
	switch v in source {
	case Text_Buffer:
		buf_byte_len := text_buffer_byte_length(v)
		byte_idx := clamp(pos, 0, buf_byte_len)

		for byte_idx < buf_byte_len {
			b, ok := text_buffer_get_byte_at(v, byte_idx)
			if !ok {
				break
			}

			if is_space(b) {
				break
			}

			byte_idx += 1
		}

		for byte_idx < buf_byte_len {
			b, ok := text_buffer_get_byte_at(v, byte_idx)
			if !ok {
				break
			}

			if !is_space(b) {
				break
			}

			byte_idx += 1
		}

		return byte_idx
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


@(private)
@(require_results)
text_source_byte_length :: proc(source: Text_Source) -> int {
	switch v in source {
	case Text_Buffer:
		return text_buffer_byte_length(v)
	case string:
		return len(v)
	}

	return -1
}

@(private)
@(require_results)
clamp_byte_pos_to_text_source_range :: proc(source: Text_Source, byte_pos: int) -> int {
	max_pos := text_source_byte_length(source)
	clamped := clamp(byte_pos, 0, max_pos)
	return clamped
}

@(private)
set_caret :: proc(state: ^Text_State, byte_pos: int) {
	source, selection := text_state_parts(state)
	clamped := clamp_byte_pos_to_text_source_range(source, byte_pos)
	selection.active = clamped
	selection.anchor = clamped
}

@(private)
set_active :: proc(state: ^Text_State, byte_pos: int) {
	source, selection := text_state_parts(state)
	clamped := clamp_byte_pos_to_text_source_range(source, byte_pos)
	selection.active = clamped
}

@(private)
@(require_results)
text_cursor_translated_pos :: proc(
	state: ^Text_State,
	translation: Translation,
	collapse_selection_lr: bool,
) -> int {

	source, selection := text_state_parts(state)

	switch translation {
	case .Left:
		if collapse_selection_lr && !is_selection_collapsed(selection^) {
			return selection_start(selection^)
		}
		_, width := text_cursor_get_prev_rune(source, selection.active)
		return selection.active - width
	case .Right:
		if collapse_selection_lr && !is_selection_collapsed(selection^) {
			return selection_end(selection^)
		}
		_, width := text_cursor_peek_rune_at_byte_offset(source, selection.active)
		return selection.active + width
	case .Next_Word:
		return text_cursor_next_word_byte_pos(source, selection.active)

	case .Prev_Word:
		return text_cursor_prev_word_byte_pos(source, selection.active)
	case .Start:
		return 0
	case .End:
		return text_source_byte_length(source)
	}

	return 0
}

@(private)
text_state_parts :: proc(state: ^Text_State) -> (source: Text_Source, selection: ^Selection) {
	switch v in state.variant {
	case Text_Edit_State:
		source = v.buffer
	case Text_Read_Only_State:
		source = v.text
	}
	selection = &state.selection
	return
}

@(private)
is_space :: proc(b: u8) -> bool {
	return b == ' ' || b == '\t' || b == '\n'
}

@(private)
is_selection_collapsed :: proc(selection: Selection) -> bool {
	return selection.active == selection.anchor
}

@(private)
keymod_has_word_move_mod :: proc(keymod: base.Keymod_Set) -> bool {
	return base.is_ctrl_down(keymod) || base.is_alt_down(keymod)
}

@(private)
keymod_has_line_move_mod :: proc(keymod: base.Keymod_Set) -> bool {
	return base.is_gui_down(keymod)
}

@(private)
translation_for_horizontal_key :: proc(
	key: base.Key,
	word_mod_down, line_mod_down: bool,
) -> Translation {
	is_left := key == .Left
	if line_mod_down {
		if is_left {
			return .Start
		}
		return .End
	}
	if word_mod_down {
		if is_left {
			return .Prev_Word
		}
		return .Next_Word
	}
	if is_left {
		return .Left
	}
	return .Right
}
