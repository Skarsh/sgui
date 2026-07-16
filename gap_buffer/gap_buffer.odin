package gap_buffer

import "core:mem"
import "core:unicode/utf8"

DEFAULT_GAP_BUFFER_SIZE :: 4096

Gap_Buffer :: struct {
	buf:       []u8,
	start:     int,
	end:       int,
	allocator: mem.Allocator,
}

@(require_results)
init_gap_buffer :: proc(
	gb: ^Gap_Buffer,
	size: int,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {
	buf := make([]u8, size, allocator) or_return
	gb.buf = buf
	gb.start = 0
	gb.end = len(buf)
	gb.allocator = allocator
	return nil
}

deinit :: proc(gb: ^Gap_Buffer) {
	delete(gb.buf, gb.allocator)
	gb^ = {}
}

// Allocates using the passed in allocator
@(require_results)
get_text :: proc(gb: Gap_Buffer, allocator: mem.Allocator) -> (string, mem.Allocator_Error) {
	res, alloc_err := make([]u8, byte_length(gb), allocator)
	if alloc_err == .None {
		// copy left
		copy(res[:gb.start], gb.buf[:gb.start])

		// copy right
		copy(res[gb.start:], gb.buf[gb.end:])
	}

	return string(res), alloc_err
}

insert_at :: proc {
	insert_byte_at,
	insert_rune_at,
	insert_slice_at,
	insert_string_at,
}

@(require_results)
insert_byte_at :: proc(gb: ^Gap_Buffer, pos: int, ch: u8) -> mem.Allocator_Error {
	assert(pos >= 0, "pos must be non-negative")
	assert(pos <= byte_length(gb^), "pos must be within the buffer contents")

	ensure_space(gb, 1) or_return
	shift_gap_to(gb, pos)
	gb.buf[gb.start] = ch
	gb.start += 1
	return nil
}

@(require_results)
insert_rune_at :: proc(gb: ^Gap_Buffer, pos: int, r: rune) -> mem.Allocator_Error {
	bytes, width := utf8.encode_rune(r)
	return insert_slice_at(gb, pos, bytes[:width])
}

@(require_results)
insert_slice_at :: proc(gb: ^Gap_Buffer, pos: int, slice: []u8) -> mem.Allocator_Error {
	assert(pos >= 0, "pos must be non-negative")
	assert(pos <= byte_length(gb^), "pos must be within the buffer contents")

	ensure_space(gb, len(slice)) or_return
	shift_gap_to(gb, pos)
	copy(gb.buf[gb.start:], slice)
	gb.start += len(slice)
	return nil
}

@(require_results)
insert_string_at :: proc(gb: ^Gap_Buffer, pos: int, str: string) -> mem.Allocator_Error {
	return insert_slice_at(gb, pos, transmute([]u8)str)
}


delete_at :: proc(gb: ^Gap_Buffer, pos: int) {
	if pos >= 0 && pos < byte_length(gb^) {
		shift_gap_to(gb, pos)
		gb.end += 1
	}
}

delete_range :: proc(gb: ^Gap_Buffer, pos: int, count: int) {
	valid_len := byte_length(gb^)
	if (pos >= 0 && pos < byte_length(gb^)) && count > 0 {

		// Clamp count so we don't delete past the end
		actual_count := min(count, valid_len - pos)

		// Move gap to start of deletion
		shift_gap_to(gb, pos)

		gb.end += actual_count
	}
}


@(require_results)
byte_length :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf) - (gb.end - gb.start)
}

@(require_results)
capacity :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf)
}

@(require_results)
gap_size :: proc(gb: Gap_Buffer) -> int {
	return gb.end - gb.start
}

@(require_results)
get_byte_at :: proc(gb: Gap_Buffer, pos: int) -> (u8, bool) {
	if pos < 0 || pos >= byte_length(gb) {
		return 0, false
	}

	if pos < gb.start {
		return gb.buf[pos], true
	}

	gap_sz := gap_size(gb)
	return gb.buf[pos + gap_sz], true
}

@(require_results)
peek_rune_at :: proc(gb: Gap_Buffer, byte_idx: int) -> (r: rune, width: int) {
	if byte_idx < gb.start {
		return utf8.decode_rune(gb.buf[byte_idx:])
	}
	physical_idx := byte_idx + gap_size(gb)

	if physical_idx < len(gb.buf) {
		return utf8.decode_rune(gb.buf[physical_idx:])
	}

	return utf8.RUNE_ERROR, 0
}

// Helper procedure to get the left and right strings of the gap
@(private)
@(require_results)
get_strings :: proc(gb: Gap_Buffer) -> (left: string, right: string) {
	left = string(gb.buf[0:gb.start])
	right = string(gb.buf[gb.end:])
	return
}

// Grows the buffer when out of space
@(private)
@(require_results)
grow :: proc(gb: ^Gap_Buffer, required: int) -> mem.Allocator_Error {
	current_len := len(gb.buf)
	new_cap := max(current_len * 2, current_len + required)

	// Amount how much bigger the buffer is getting
	amount_grown := new_cap - current_len

	new_buf := make([]u8, new_cap, gb.allocator) or_return

	// Copy data before the gap
	copy(new_buf[:gb.start], gb.buf[:gb.start])

	// Calculate new end
	new_end := gb.end + amount_grown

	// Copy right side
	copy(new_buf[new_end:], gb.buf[gb.end:])

	delete(gb.buf, gb.allocator)
	gb.buf = new_buf
	gb.end = new_end

	return nil
}

// Helper to ensure we grow if we don't have enough space
@(private)
@(require_results)
ensure_space :: proc(gb: ^Gap_Buffer, amount: int) -> mem.Allocator_Error {
	if gap_size(gb^) < amount {
		grow(gb, amount) or_return
	}
	return nil
}

// TODO(Thomas): @Perf - Can we do some copy here when
// the jump is big?
// Shifts the gap to position given in the buf
// pos should be valid here due to checks from the callers.
@(private)
shift_gap_to :: proc(gb: ^Gap_Buffer, pos: int) {
	// Before moving 1 right
	// abcd____efgh
	//    ^    ^

	// After moving 1 right
	// abcde____fgh
	//     ^    ^

	// Moving gap right, so need to copy chars to the left
	for gb.start < pos {
		gb.buf[gb.start] = gb.buf[gb.end]
		gb.start += 1
		gb.end += 1
	}

	// Before moving 1 left
	// abcd____efgh
	//    ^    ^

	// After moving 1 left
	// abc____defgh
	//   ^    ^

	// Moving gap left, so need to copy chars to the right
	for pos < gb.start {
		gb.start -= 1
		gb.end -= 1
		gb.buf[gb.end] = gb.buf[gb.start]
	}
}
