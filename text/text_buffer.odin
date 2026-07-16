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
Text_Buffer :: struct {
	buf: Backing_Buffer,
}

Text_Buffer_Error :: union #shared_nil {
	fixed_buffer.Fixed_Buffer_Error,
	mem.Allocator_Error,
}

text_buffer_deinit :: proc(tb: ^Text_Buffer) {
	switch &buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		gap_buffer.deinit(&buf)
	case fixed_buffer.Fixed_Buffer:
		fixed_buffer.deinit(&buf)
	}
}

@(require_results)
text_buffer_insert_at :: proc(tb: ^Text_Buffer, byte_pos: int, str: string) -> Text_Buffer_Error {
	switch &buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		byte_idx := clamp(byte_pos, 0, gap_buffer.byte_length(buf))
		gap_buffer.insert_at(&buf, byte_idx, str) or_return
	case fixed_buffer.Fixed_Buffer:
		byte_idx := clamp(byte_pos, 0, buf.len)
		fixed_buffer.insert_at(&buf, byte_idx, str) or_return
	}
	return nil
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

text_buffer_text :: proc(
	tb: Text_Buffer,
	allocator: mem.Allocator,
) -> (
	string,
	mem.Allocator_Error,
) {
	str: string
	alloc_err: mem.Allocator_Error
	switch buf in tb.buf {
	case gap_buffer.Gap_Buffer:
		str, alloc_err = gap_buffer.get_text(buf, allocator)
	case fixed_buffer.Fixed_Buffer:
		str = fixed_buffer.get_text(buf)
	}

	return str, alloc_err
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
