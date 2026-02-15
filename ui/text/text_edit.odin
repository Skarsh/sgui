package text

import "core:mem"

import "../../base"

Selection :: struct {
	anchor: int,
	active: int,
}

Text_Edit_State :: struct {
	buffer: Text_Buffer,
	cursor: int,
}

text_edit_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Edit_State {
	text_buf := text_buffer_init(allocator)
	return Text_Edit_State{buffer = text_buf}
}

text_edit_handle_key :: proc(state: ^Text_Edit_State, key: base.Key) {

}

// TOOD(Thomas): Add handling of drag and double/triple click
text_edit_handle_click :: proc(state: ^Text_Edit_State, layout: ^Text_Layout_Cache) {}

text_edit_insert :: proc(state: ^Text_Edit_State, text: string) {

}
