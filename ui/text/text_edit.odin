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
	case .Right:
	case:
		log.error("Illegal key")
	}
}


// TOOD(Thomas): Add handling of drag and double/triple click
text_edit_handle_click :: proc(state: ^Text_Edit_State, layout: ^Text_Layout_Cache) {}

text_edit_insert :: proc(state: ^Text_Edit_State, text: string) {

}
