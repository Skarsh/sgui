package ui

import "core:mem"

import gap_buffer "../gap_buffer"

// Text_Buffer is meant to be an abstraction providing a simple text manipulation
// API on top of varying data structures e.g. Gap_Buffer, Rope etc.

Move_Direction :: enum {
	Left,
	Right,
	Up,
	Down,
	Word_Left,
	Word_Right,
	Line_Start,
	Line_End,
}

// TODO(Thomas): Add another backing data structure to see how the API holds
Text_Buffer :: struct {
	gb: gap_buffer.Gap_Buffer,
}

DEFAULT_GAP_BUFFER_SIZE :: 4096

text_buffer_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Buffer {
	gb := gap_buffer.init_gap_buffer(4096, allocator)
	return Text_Buffer{gb = gb}
}

text_buffer_init_with_content :: proc(content: string, allocator: mem.Allocator) -> Text_Buffer {
	str_len := len(content)
	buf_len := max(2 * str_len, DEFAULT_GAP_BUFFER_SIZE)
	gb := gap_buffer.init_gap_buffer(buf_len, allocator)
	gap_buffer.insert_at(&gb, 0, content)
	return Text_Buffer{gb = gb}
}

text_buffer_deinit :: proc(buf: ^Text_Buffer) {
	gap_buffer.deinit(&buf.gb)
}

text_buffer_insert_at :: proc(buf: ^Text_Buffer, pos: int, str: string) {
	gap_buffer.insert_at(&buf.gb, pos, str)
}

text_buffer_delete_at :: proc(buf: ^Text_Buffer, pos: int) {
	gap_buffer.delete_at(&buf.gb, pos)
}

text_buffer_delete_range :: proc(buf: ^Text_Buffer, pos: int, count: int)
