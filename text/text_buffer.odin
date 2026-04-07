package text

import "core:mem"
import "core:unicode/utf8"

import gap_buffer "../gap_buffer"
import fixed_buffer "fixed_buffer"

Backing_Buffer :: union {
	gap_buffer.Gap_Buffer,
	fixed_buffer.Fixed_Buffer,
}

// Text_Buffer is meant to be an abstraction providing a simple text manipulation
// API on top of varying data structures e.g. Gap_Buffer, Rope etc.

// TODO(Thomas): Add another backing data structure to see how the API holds
Text_Buffer :: struct {
	buf: Backing_Buffer,
}

DEFAULT_GAP_BUFFER_SIZE :: 4096

text_buffer_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Buffer {
	gb := gap_buffer.init_gap_buffer(DEFAULT_GAP_BUFFER_SIZE, allocator)
	return Text_Buffer{buf = gb}
}

text_buffer_init_with_content :: proc(content: string, allocator: mem.Allocator) -> Text_Buffer {
	str_len := len(content)
	buf_len := max(2 * str_len, DEFAULT_GAP_BUFFER_SIZE)

	gb := gap_buffer.init_gap_buffer(buf_len, allocator)
	gap_buffer.insert_at(&gb, 0, content)

	return Text_Buffer{buf = gb}
}

text_buffer_deinit :: proc(tb: ^Text_Buffer) {
	switch &buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		gap_buffer.deinit(&buf)
	case fixed_buffer.Fixed_Buffer:
		fixed_buffer.deinit(&buf)
	}
}

text_buffer_insert_at :: proc(tb: ^Text_Buffer, byte_pos: int, str: string) {
	switch &buf in tb.buf {

	case gap_buffer.Gap_Buffer:
		byte_idx := clamp(byte_pos, 0, gap_buffer.byte_length(buf))
		gap_buffer.insert_at(&buf, byte_idx, str)
	case fixed_buffer.Fixed_Buffer:
		byte_idx := clamp(byte_pos, 0, buf.len)
		fixed_buffer.insert_at(&buf, byte_idx, str)
	}
}

text_buffer_delete_range :: proc(tb: ^Text_Buffer, byte_pos: int, byte_count: int) {
	switch &buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		gap_buffer.delete_range(&buf, byte_pos, byte_count)
	case fixed_buffer.Fixed_Buffer:
		fixed_buffer.delete_range(&buf, byte_pos, byte_count)
	}
}

text_buffer_byte_length :: proc(tb: Text_Buffer) -> int {
	byte_len: int
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		byte_len = gap_buffer.byte_length(buf)
	case fixed_buffer.Fixed_Buffer:
		byte_len = buf.len
	}
	return byte_len
}

text_buffer_capacity :: proc(tb: Text_Buffer) -> int {
	byte_len: int
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		byte_len = gap_buffer.capacity(buf)
	case fixed_buffer.Fixed_Buffer:
		byte_len = fixed_buffer.capacity(buf)
	}

	return byte_len
}

// Allocated using the passed in allocator
text_buffer_text :: proc(tb: Text_Buffer, allocator: mem.Allocator) -> string {
	str: string
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		str = gap_buffer.get_text(buf, allocator)
	case fixed_buffer.Fixed_Buffer:
		str = fixed_buffer.contents_string(buf)
	}

	return str
}

text_buffer_get_byte_at :: proc(tb: Text_Buffer, byte_idx: int) -> (u8, bool) {
	b: u8 = 0
	ok: bool = false
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		b, ok = gap_buffer.get_byte_at(buf, byte_idx)
	case fixed_buffer.Fixed_Buffer:
		b, ok = fixed_buffer.get_byte_at(buf, byte_idx)
	}

	return b, ok
}

text_buffer_prev_word_byte_pos :: proc(buf: Text_Buffer, pos: int) -> int {
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

text_buffer_next_word_byte_pos :: proc(buf: Text_Buffer, pos: int) -> int {
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
get_prev_rune :: proc(buf: Text_Buffer, byte_idx: int) -> (rune, int) {
	r: rune = utf8.RUNE_ERROR
	width: int = 0
	if byte_idx <= 0 {
		return 0, 0
	}

	start := byte_idx - 1
	for _ in 0 ..< utf8.UTF_MAX {
		if start < 0 {
			break
		}

		b, ok := text_buffer_get_byte_at(buf, start)
		assert(ok)

		if utf8.rune_start(b) {
			break
		}

		start -= 1
	}

	r, width = peek_rune_at_byte_offset(buf, start)
	return r, width
}

@(private)
peek_rune_at_byte_offset :: proc(tb: Text_Buffer, byte_idx: int) -> (rune, int) {
	r: rune = utf8.RUNE_ERROR
	width: int = 0
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		r, width = gap_buffer.peek_rune_at(buf, byte_idx)
	case fixed_buffer.Fixed_Buffer:
		r, width = fixed_buffer.peek_rune_at(buf, byte_idx)
	}

	return r, width
}
