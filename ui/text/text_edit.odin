package text

import "core:log"
import "core:mem"

import "../../base"

// Base on this RXI article
// https://rxi.github.io/textbox_behaviour.html

// Byte indexes
Selection :: struct {
	active: int,
	anchor: int,
}

Text_Edit_State :: struct {
	buffer:    Text_Buffer,
	selection: Selection,
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

text_edit_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Edit_State {
	text_buf := text_buffer_init(allocator)
	return Text_Edit_State{buffer = text_buf, selection = {active = 0, anchor = 0}}
}

// TODO(Thomas): Expand command wiring for more shortcuts (select-all, clipboard, undo/redo).
text_edit_handle_keys :: proc(
	state: ^Text_Edit_State,
	keys: base.Key_Set,
	keymod: base.Keymod_Set = base.KMOD_NONE,
) {
	shift_down := keymod_has_shift(keymod)
	word_mod_down := keymod_has_word_move_mod(keymod)
	line_mod_down := keymod_has_line_move_mod(keymod)

	for key in keys {
		#partial switch key {
		case .A:
		// TODO(Thomas): Select-all
		case .C:
		// TODO(Thomas): Copy selection
		case .V:
		// TODO(Thomas): Paste selection
		case .X:
		// TODO(Thomas): Cut selection
		case .Y:
		// TODO(Thomas): Redo
		case .Z:
		// TODO(Thomas): Undo
		case .Left:
			translation := translation_for_horizontal_key(key, word_mod_down, line_mod_down)
			apply_move_or_select(state, translation, shift_down)
		case .Right:
			translation := translation_for_horizontal_key(key, word_mod_down, line_mod_down)
			apply_move_or_select(state, translation, shift_down)
		case .Home:
			apply_move_or_select(state, .Start, shift_down)
		case .End:
			apply_move_or_select(state, .End, shift_down)
		case .Backspace:
			translation: Translation = .Left
			if word_mod_down {
				translation = .Prev_Word
			}
			text_edit_delete_to(state, translation)
		case .Delete:
			translation: Translation = .Right
			if word_mod_down {
				translation = .Next_Word
			}
			text_edit_delete_to(state, translation)
		case .Tab:
			text_edit_insert(state, "\t")
		}
	}

}

text_edit_move_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	target := translated_pos(state, translation, true)
	set_caret(state, target)
}

text_edit_select_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	target := translated_pos(state, translation, false)
	set_active(state, target)
}

text_edit_delete_to :: proc(state: ^Text_Edit_State, translation: Translation) {

	if !is_selection_collapsed(state.selection) {
		start := selection_start(state.selection)
		end := selection_end(state.selection)
		text_buffer_delete_range(&state.buffer, start, end - start)
		set_caret(state, start)
		return
	}

	from := state.selection.active
	to := translated_pos(state, translation, false)
	start := min(from, to)
	end := max(from, to)
	if start == end {
		return
	}

	text_buffer_delete_range(&state.buffer, start, end - start)
	set_caret(state, start)
}

// TOOD(Thomas): Add handling of drag and double/triple click
text_edit_handle_click :: proc(state: ^Text_Edit_State, layout: ^Text_Layout_Cache) {}

text_edit_insert :: proc(state: ^Text_Edit_State, text: string) {
	insert_at := state.selection.active
	if !is_selection_collapsed(state.selection) {
		start := selection_start(state.selection)
		end := selection_end(state.selection)
		text_buffer_delete_range(&state.buffer, start, end - start)
		insert_at = start
	}

	text_buffer_insert_at(&state.buffer, insert_at, text)
	set_caret(state, insert_at + len(text))
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
		return text_buffer_next_word_byte_pos(state.buffer, state.selection.active)
	case .Prev_Word:
		return text_buffer_prev_word_byte_pos(state.buffer, state.selection.active)
	case .Start:
		return 0
	case .End:
		return text_buffer_byte_length(state.buffer)
	}

	return state.selection.active
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
selection_start :: proc(selection: Selection) -> int {
	return min(selection.active, selection.anchor)
}

@(private)
selection_end :: proc(selection: Selection) -> int {
	return max(selection.active, selection.anchor)
}

@(private)
keymod_has_shift :: proc(keymod: base.Keymod_Set) -> bool {
	return .LSHIFT in keymod || .RSHIFT in keymod
}

@(private)
keymod_has_word_move_mod :: proc(keymod: base.Keymod_Set) -> bool {
	return .LCTRL in keymod || .RCTRL in keymod || .LALT in keymod || .RALT in keymod
}

@(private)
keymod_has_line_move_mod :: proc(keymod: base.Keymod_Set) -> bool {
	return .LGUI in keymod || .RGUI in keymod
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
