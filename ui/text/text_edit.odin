package text

import "core:log"
import "core:mem"

import "../../base"

// Base on this RXI article
// https://rxi.github.io/textbox_behaviour.html

// Rune indexes
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


text_edit_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Edit_State {
	text_buf := text_buffer_init(allocator)
	return Text_Edit_State{buffer = text_buf, selection = {active = 0, anchor = 0}}
}

// TODO(Thomas): Hardcoded Rune movement for now
text_edit_handle_key :: proc(state: ^Text_Edit_State, key: base.Key) {
	#partial switch key {
	case .Left:
		text_edit_move_to(state, .Left)
	case .Right:
	case:
		log.error("Illegal key")
	}
}

text_edit_move_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	switch translation {
	case .Left:
		if !is_selection_collapsed(state.selection) {
			set_caret(state, selection_start(state.selection))
		} else {
			set_caret(state, state.selection.active - 1)
		}
	case .Right:
		if !is_selection_collapsed(state.selection) {
			set_caret(state, selection_end(state.selection))
		} else {
			set_caret(state, state.selection.active + 1)
		}
	case .Next_Word:
		set_caret(state, text_buffer_next_word_rune_pos(state.buffer, state.selection.active))
	case .Prev_Word:
		set_caret(state, text_buffer_prev_word_rune_pos(state.buffer, state.selection.active))
	case .Start:
		set_caret(state, 0)
	case .End:
		set_caret(state, text_buffer_rune_len(state.buffer))
	}
}

text_edit_select_to :: proc(state: ^Text_Edit_State, translation: Translation) {
	switch translation {
	case .Left:
		set_active(state, state.selection.active - 1)
	case .Right:
	case .Next_Word:
	case .Prev_Word:
	case .Start:
	case .End:
	}
}

text_edit_delete_to :: proc(state: ^Text_Edit_State, translation: Translation) {}

// TOOD(Thomas): Add handling of drag and double/triple click
text_edit_handle_click :: proc(state: ^Text_Edit_State, layout: ^Text_Layout_Cache) {}

text_edit_insert :: proc(state: ^Text_Edit_State, text: string) {}

@(private)
clamp_rune_pos_to_text_buffer_range :: proc(buffer: Text_Buffer, rune_pos: int) -> int {
	max_pos := text_buffer_rune_len(buffer)
	clamped := max(0, min(rune_pos, max_pos))
	return clamped
}

@(private)
set_caret :: proc(state: ^Text_Edit_State, rune_pos: int) {
	clamped := clamp_rune_pos_to_text_buffer_range(state.buffer, rune_pos)
	state.selection.active = clamped
	state.selection.anchor = clamped
}

@(private)
set_active :: proc(state: ^Text_Edit_State, rune_pos: int) {
	clamped := clamp_rune_pos_to_text_buffer_range(state.buffer, rune_pos)
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
