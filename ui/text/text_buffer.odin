package text

import "core:mem"
import "core:unicode/utf8"

import gap_buffer "../../gap_buffer"

// Text_Buffer is meant to be an abstraction providing a simple text manipulation
// API on top of varying data structures e.g. Gap_Buffer, Rope etc.

// TODO(Thomas): Add another backing data structure to see how the API holds
Text_Buffer :: struct {
	gb:                gap_buffer.Gap_Buffer,
	cached_rune_count: int,
}

DEFAULT_GAP_BUFFER_SIZE :: 4096

text_buffer_init :: proc(allocator: mem.Allocator = context.allocator) -> Text_Buffer {
	gb := gap_buffer.init_gap_buffer(DEFAULT_GAP_BUFFER_SIZE, allocator)
	return Text_Buffer{gb = gb, cached_rune_count = 0}
}

text_buffer_init_with_content :: proc(content: string, allocator: mem.Allocator) -> Text_Buffer {
	str_len := len(content)
	buf_len := max(2 * str_len, DEFAULT_GAP_BUFFER_SIZE)

	gb := gap_buffer.init_gap_buffer(buf_len, allocator)
	gap_buffer.insert_at(&gb, 0, content)

	return Text_Buffer {
		gb                = gb,
		// Calculate initial rune count
		cached_rune_count = utf8.rune_count_in_string(content),
	}
}

text_buffer_deinit :: proc(buf: ^Text_Buffer) {
	gap_buffer.deinit(&buf.gb)
}

// TODO(Thomas): Clamp better here instead of relying on rune_index_to_byte_index??
text_buffer_insert_at :: proc(buf: ^Text_Buffer, rune_pos: int, str: string) {
	byte_idx := rune_index_to_byte_index(buf.gb, rune_pos)
	gap_buffer.insert_at(&buf.gb, byte_idx, str)
	buf.cached_rune_count += utf8.rune_count_in_string(str)
}

text_buffer_delete_at :: proc(buf: ^Text_Buffer, rune_pos: int) {
	if rune_pos < 0 || rune_pos >= buf.cached_rune_count {
		return
	}

	byte_idx := rune_index_to_byte_index(buf.gb, rune_pos)
	_, width := peek_rune_at_byte_offset(buf.gb, byte_idx)
	gap_buffer.delete_range(&buf.gb, byte_idx, width)

	buf.cached_rune_count -= 1
}

text_buffer_delete_range :: proc(buf: ^Text_Buffer, rune_pos: int, rune_count: int) {
	if rune_count <= 0 || rune_pos < 0 || rune_pos >= buf.cached_rune_count {
		return
	}

	// Clamp count so we don't go out of bounds
	actual_count := min(rune_count, buf.cached_rune_count - rune_pos)

	start_byte_idx := rune_index_to_byte_index(buf.gb, rune_pos)
	end_byte_idx := rune_index_to_byte_index(buf.gb, rune_pos + actual_count)

	byte_count := end_byte_idx - start_byte_idx

	gap_buffer.delete_range(&buf.gb, start_byte_idx, byte_count)

	buf.cached_rune_count -= actual_count
}

text_buffer_byte_len :: proc(buf: Text_Buffer) -> (byte_length: int) {
	return gap_buffer.byte_length(buf.gb)
}

text_buffer_rune_len :: proc(buf: Text_Buffer) -> (rune_length: int) {
	return buf.cached_rune_count
}

text_buffer_capacity :: proc(buf: Text_Buffer) -> (byte_length: int) {
	return gap_buffer.capacity(buf.gb)
}

// NOTE - This allocates using Text_Buffer owned allocator,
text_buffer_text :: proc(buf: Text_Buffer) -> string {
	return gap_buffer.get_text(buf.gb)
}

@(private)
// Scans the Gap_Buffer (skipping the gap) to find the Byte Offset for specific Rune Index.
// Complexity O(N)
rune_index_to_byte_index :: proc(gb: gap_buffer.Gap_Buffer, target_rune: int) -> int {
	if target_rune <= 0 {
		return 0
	}

	current_rune := 0
	byte_offset := 0

	// Scan before the gap
	idx := 0
	for idx < gb.start {
		if current_rune == target_rune {
			return byte_offset
		}

		_, width := utf8.decode_rune(gb.buf[idx:gb.start])
		idx += width
		byte_offset += width
		current_rune += 1
	}

	// Scan after the gap
	idx = gb.end
	for idx < len(gb.buf) {
		if current_rune == target_rune {
			return byte_offset
		}
		_, width := utf8.decode_rune(gb.buf[idx:])
		idx += width
		byte_offset += width
		current_rune += 1
	}

	return byte_offset
}

@(private)
peek_rune_at_byte_offset :: proc(
	gb: gap_buffer.Gap_Buffer,
	byte_idx: int,
) -> (
	r: rune,
	width: int,
) {

	if byte_idx < gb.start {
		return utf8.decode_rune(gb.buf[byte_idx:])
	}

	gap_sz := gap_buffer.gap_size(gb)
	physical_idx := byte_idx + gap_sz

	if physical_idx < len(gb.buf) {
		return utf8.decode_rune(gb.buf[physical_idx:])
	}

	return utf8.RUNE_ERROR, 0
}
