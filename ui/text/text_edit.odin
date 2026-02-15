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

text_edit_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Edit_State {
	text_buf := text_buffer_init(allocator)
	return Text_Edit_State{buffer = text_buf}
}

// TODO(Thomas): Hardcoded Rune movement for now
text_edit_handle_key :: proc(state: ^Text_Edit_State, key: base.Key) {
	#partial switch key {
	case .Left:
		text_edit_move_to(state, text_edit_move_left)
	case .Right:
	case:
		log.error("Illegal key")
	}
}

// Moves the position of the caret (both anchor and active index of the Selection)
text_edit_move_to :: proc(
	state: ^Text_Edit_State,
	movement: proc(text_edit_state: ^Text_Edit_State),
) {
	movement(state)
}

// Moves only the active index of the Selection, leaves the Anchor unchanged
text_edit_select_to :: proc(state: ^Text_Edit_State) {

}

// Deletes everything between the caret and the resultant position
text_edit_delete_to :: proc(state: ^Text_Edit_State) {

}

// Move caret (both active and anchor in Selection) one character (Rune) to the left
text_edit_move_left :: proc(state: ^Text_Edit_State) {

	// Check if moving one left is legal

	state.selection.anchor -= 1
	state.selection.active -= 1
}


// TOOD(Thomas): Add handling of drag and double/triple click
text_edit_handle_click :: proc(state: ^Text_Edit_State, layout: ^Text_Layout_Cache) {}

text_edit_insert :: proc(state: ^Text_Edit_State, text: string) {

}
