package text

import "core:mem"
import "core:unicode/utf8"

import gap_buffer "../gap_buffer"

// Text_Buffer is meant to be an abstraction providing a simple text manipulation
// API on top of varying data structures e.g. Gap_Buffer, Rope etc.

// TODO(Thomas): Add another backing data structure to see how the API holds
Text_Buffer :: struct {
	gb: gap_buffer.Gap_Buffer,
}

DEFAULT_GAP_BUFFER_SIZE :: 4096

text_buffer_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Buffer {
	gb := gap_buffer.init_gap_buffer(DEFAULT_GAP_BUFFER_SIZE, allocator)
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

text_buffer_insert_at :: proc(buf: ^Text_Buffer, byte_pos: int, str: string) {
	byte_idx := clamp(byte_pos, 0, gap_buffer.byte_length(buf.gb))
	gap_buffer.insert_at(&buf.gb, byte_idx, str)
}

text_buffer_delete_range :: proc(buf: ^Text_Buffer, byte_pos: int, byte_count: int) {
	gap_buffer.delete_range(&buf.gb, byte_pos, byte_count)
}

text_buffer_byte_length :: proc(buf: Text_Buffer) -> (byte_length: int) {
	return gap_buffer.byte_length(buf.gb)
}

text_buffer_capacity :: proc(buf: Text_Buffer) -> (byte_length: int) {
	return gap_buffer.capacity(buf.gb)
}

// Allocated using the passed in allocator
text_buffer_text :: proc(buf: Text_Buffer, allocator: mem.Allocator) -> string {
	return gap_buffer.get_text(buf.gb, allocator)
}

text_buffer_get_byte_at :: proc(buf: Text_Buffer, byte_idx: int) -> (u8, bool) {
	return gap_buffer.get_byte_at(buf.gb, byte_idx)
}

text_buffer_copy_into :: proc(buf: Text_Buffer, dst: []u8) -> int {
	// TODO(Thomas): Replace iterator copy with a 2-slice bulk copy (left + right of gap)
	// to reduce per-byte overhead in text input hot paths.
	limit := min(len(dst), text_buffer_byte_length(buf))
	if limit <= 0 {
		return 0
	}

	it := gap_buffer.init_gap_buffer_iterator(buf.gb)
	written := 0
	for written < limit {
		b, _, ok := gap_buffer.gap_buffer_iterator_next(&it)
		if !ok {
			break
		}
		dst[written] = b
		written += 1
	}

	return written
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
get_prev_rune :: proc(buf: Text_Buffer, byte_idx: int) -> (r: rune, width: int) {
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
	return
}

@(private)
peek_rune_at_byte_offset :: proc(buf: Text_Buffer, byte_idx: int) -> (r: rune, width: int) {

	if byte_idx < buf.gb.start {
		return utf8.decode_rune(buf.gb.buf[byte_idx:])
	}

	gap_sz := gap_buffer.gap_size(buf.gb)
	physical_idx := byte_idx + gap_sz

	if physical_idx < len(buf.gb.buf) {
		return utf8.decode_rune(buf.gb.buf[physical_idx:])
	}

	return utf8.RUNE_ERROR, 0
}
