package text

import "../base"

// Based on this RXI article
// https://rxi.github.io/textbox_behaviour.html

// Byte indexes
Selection :: struct {
	active: int,
	anchor: int,
}

Text_Edit_State :: struct {
	buffer:    Text_Buffer,
	selection: Selection,
	max_len:   int,
}

Translation :: enum {
	Left,
	Right,
	Next_Word,
	Prev_Word,
	Start,
	End,
}

Text_Edit_Clipboard_Command :: enum {
	None,
	Copy,
	Paste,
	Cut,
}

Cmd_Move :: struct {
	translation: Translation,
	select:      bool,
}

Cmd_Set_Caret :: struct {
	byte_pos: int,
	extend:   bool,
}

Cmd_Insert :: struct {
	text: string,
}

Cmd_Delete :: struct {
	translation: Translation,
}

Cmd_Select_All :: struct {}

Text_Edit_Command :: union {
	Cmd_Move,
	Cmd_Set_Caret,
	Cmd_Insert,
	Cmd_Delete,
	Cmd_Select_All,
}

text_edit_init :: proc(state: ^Text_Edit_State, buffer: Text_Buffer, max_len: int = max(int)) {
	state.buffer = buffer
	state.selection = {}
	state.max_len = max_len
}

text_edit_deinit :: proc(state: ^Text_Edit_State) {
	text_buffer_deinit(&state.buffer)
}

// Editing keys go through translate_key and text_edit_apply.
// TODO(Thomas): Move clipboard and undo/redo out to the ui/glue layer.
text_edit_handle_keys :: proc(
	state: ^Text_Edit_State,
	keys: base.Key_Set,
	keymod: base.Keymod_Set = base.KMOD_NONE,
) -> (
	clipboard_command: Text_Edit_Clipboard_Command,
	text_buffer_error: Text_Buffer_Error,
) {
	ctrl_down := base.is_ctrl_down(keymod)

	for key in keys {
		// Editing keys go through the command pipeline.
		if cmd, ok := translate_key(key, keymod); ok {
			text_edit_apply(state, cmd) or_return
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

	return clipboard_command, nil
}

// Maps a key press and its modifiers to an editing command.
// Returns ok=false for keys we don't handle here, like clipboard and undo/redo.
@(private)
translate_key :: proc(
	key: base.Key,
	keymod: base.Keymod_Set,
) -> (
	cmd: Text_Edit_Command,
	ok: bool,
) {
	shift_down := base.is_shift_down(keymod)
	ctrl_down := base.is_ctrl_down(keymod)
	word_mod_down := keymod_has_word_move_mod(keymod)
	line_mod_down := keymod_has_line_move_mod(keymod)

	#partial switch key {
	case .A:
		if ctrl_down {
			return Cmd_Select_All{}, true
		}
	case .Left, .Right:
		translation := translation_for_horizontal_key(key, word_mod_down, line_mod_down)
		return Cmd_Move{translation = translation, select = shift_down}, true
	case .Home:
		return Cmd_Move{translation = .Start, select = shift_down}, true
	case .End:
		return Cmd_Move{translation = .End, select = shift_down}, true
	case .Backspace:
		translation: Translation = .Left
		if word_mod_down {
			translation = .Prev_Word
		}
		return Cmd_Delete{translation = translation}, true
	case .Delete:
		translation: Translation = .Right
		if word_mod_down {
			translation = .Next_Word
		}
		return Cmd_Delete{translation = translation}, true
	case .Tab:
		return Cmd_Insert{text = "\t"}, true
	}

	return nil, false
}

@(private)
text_edit_move_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	target := translated_pos(state, translation, true)
	set_caret(state, target)
}

@(private)
text_edit_select_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	target := translated_pos(state, translation, false)
	set_active(state, target)
}

@(private)
text_edit_delete_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	if is_selection_collapsed(state.selection) {
		text_edit_select_to(state, translation)
	}

	start := selection_start(state.selection)
	end := selection_end(state.selection)
	if start != end {
		text_buffer_delete_range(&state.buffer, start, end - start)
	}
	set_caret(state, start)
}

// Applies a single editing command to the state.
// Keyboard and mouse input both translate into commands and go through here.
@(require_results)
text_edit_apply :: proc(state: ^Text_Edit_State, cmd: Text_Edit_Command) -> Text_Buffer_Error {
	switch c in cmd {
	case Cmd_Move:
		apply_move_or_select(state, c.translation, c.select)
	case Cmd_Set_Caret:
		if c.extend {
			set_active(state, c.byte_pos)
		} else {
			set_caret(state, c.byte_pos)
		}
	case Cmd_Insert:
		text_edit_insert(state, c.text) or_return
	case Cmd_Delete:
		text_edit_delete_to(state, c.translation)
	case Cmd_Select_All:
		state.selection.anchor = 0
		state.selection.active = text_buffer_byte_length(state.buffer)
	}
	return nil
}

@(require_results)
text_edit_insert :: proc(state: ^Text_Edit_State, text: string) -> Text_Buffer_Error {
	insert_at := state.selection.active
	if !is_selection_collapsed(state.selection) {
		start := selection_start(state.selection)
		end := selection_end(state.selection)
		text_buffer_delete_range(&state.buffer, start, end - start)
		insert_at = start
	}

	current_len := text_buffer_byte_length(state.buffer)
	if current_len + len(text) <= state.max_len {
		// TODO(Thomas): Properly handle error
		text_buffer_insert_at(&state.buffer, insert_at, text) or_return
		set_caret(state, insert_at + len(text))
	}

	return nil
}

selection_start :: proc(selection: Selection) -> int {
	return min(selection.active, selection.anchor)
}

selection_end :: proc(selection: Selection) -> int {
	return max(selection.active, selection.anchor)
}

// NOTE(Thomas): We are translating by runes here, later probably grapheme clusters.
@(private)
translated_pos :: proc(
	state: ^Text_Edit_State,
	translation: Translation,
	collapse_selection_lr: bool,
) -> int {
	// `collapse_selection_lr` affects only .Left/.Right with a non-collapsed selection:
	// true  = collapse to selection boundary first (used by text_edit_move_to)
	// false = translate from current active position (used by text_edit_select_to/delete_to)
	switch translation {
	case .Left:
		if collapse_selection_lr && !is_selection_collapsed(state.selection) {
			return selection_start(state.selection)
		}
		_, width := get_prev_rune(state.buffer, state.selection.active)
		return state.selection.active - width
	case .Right:
		if collapse_selection_lr && !is_selection_collapsed(state.selection) {
			return selection_end(state.selection)
		}
		_, width := peek_rune_at_byte_offset(state.buffer, state.selection.active)
		return state.selection.active + width
	case .Next_Word:
		return next_word_byte_pos(state.buffer, state.selection.active)
	case .Prev_Word:
		return prev_word_byte_pos(state.buffer, state.selection.active)
	case .Start:
		return 0
	case .End:
		return text_buffer_byte_length(state.buffer)
	}

	return state.selection.active
}

@(private)
prev_word_byte_pos :: proc(buf: Text_Buffer, pos: int) -> int {
	byte_idx := clamp(pos, 0, text_buffer_byte_length(buf))

	for byte_idx > 0 {
		b, ok := text_buffer_get_byte_at(buf, byte_idx - 1)
		if !ok {
			break
		}

		if !is_space(b) {
			break
		}

		byte_idx -= 1
	}

	for byte_idx > 0 {
		b, ok := text_buffer_get_byte_at(buf, byte_idx - 1)
		if !ok {
			break
		}

		if is_space(b) {
			break
		}

		byte_idx -= 1
	}

	return byte_idx
}

@(private)
next_word_byte_pos :: proc(buf: Text_Buffer, pos: int) -> int {
	buf_byte_len := text_buffer_byte_length(buf)
	byte_idx := clamp(pos, 0, buf_byte_len)

	for byte_idx < buf_byte_len {
		b, ok := text_buffer_get_byte_at(buf, byte_idx)
		if !ok {
			break
		}

		if is_space(b) {
			break
		}

		byte_idx += 1
	}

	for byte_idx < buf_byte_len {
		b, ok := text_buffer_get_byte_at(buf, byte_idx)
		if !ok {
			break
		}

		if !is_space(b) {
			break
		}

		byte_idx += 1
	}

	return byte_idx
}

@(private)
is_space :: proc(b: u8) -> bool {
	return b == ' ' || b == '\t' || b == '\n'
}

@(private)
clamp_byte_pos_to_text_buffer_range :: proc(buffer: Text_Buffer, byte_pos: int) -> int {
	max_pos := text_buffer_byte_length(buffer)
	clamped := clamp(byte_pos, 0, max_pos)
	return clamped
}

@(private)
set_caret :: proc(state: ^Text_Edit_State, byte_pos: int) {
	clamped := clamp_byte_pos_to_text_buffer_range(state.buffer, byte_pos)
	state.selection.active = clamped
	state.selection.anchor = clamped
}

@(private)
set_active :: proc(state: ^Text_Edit_State, byte_pos: int) {
	clamped := clamp_byte_pos_to_text_buffer_range(state.buffer, byte_pos)
	state.selection.active = clamped
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

@(private)
apply_move_or_select :: proc(state: ^Text_Edit_State, translation: Translation, select: bool) {
	if select {
		text_edit_select_to(state, translation)
	} else {
		text_edit_move_to(state, translation)
	}
}
