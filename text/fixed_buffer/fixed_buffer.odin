package fixed_buffer

import "core:unicode/utf8"

Fixed_Buffer :: struct {
	buf: []u8,
	len: int,
}

Fixed_Buffer_Error :: enum {
	None = 0,
	Buffer_Full,
}

init_with_content :: proc(fb: ^Fixed_Buffer, buf: []u8, content: []u8) {
	assert(len(content) <= len(buf))
	n := min(len(buf), len(content))
	copy(buf[:n], content[:n])
	fb.buf = buf
	fb.len = n
}

deinit :: proc(fb: ^Fixed_Buffer) {}

capacity :: proc(fb: Fixed_Buffer) -> int {
	return len(fb.buf)
}

remaining :: proc(fb: Fixed_Buffer) -> int {
	return len(fb.buf) - fb.len
}

contents_slice :: proc(fb: Fixed_Buffer) -> []u8 {
	return fb.buf[:fb.len]
}

contents_string :: proc(fb: Fixed_Buffer) -> string {
	return string(fb.buf[:fb.len])
}

insert_at :: proc {
	insert_slice_at,
	insert_byte_at,
	insert_rune_at,
	insert_string_at,
}

@(require_results)
insert_slice_at :: proc(fb: ^Fixed_Buffer, pos: int, bytes: []u8) -> (err: Fixed_Buffer_Error) {
	assert(pos >= 0, "pos must be non-negative")
	assert(pos <= fb.len, "pos must be within the buffer contents")

	if len(bytes) <= remaining(fb^) {
		// Shift existing data right
		copy(fb.buf[pos + len(bytes):], fb.buf[pos:fb.len])

		// Insert new data
		copy(fb.buf[pos:], bytes)
		fb.len += len(bytes)
	} else {
		err = .Buffer_Full
	}

	return
}

@(require_results)
insert_byte_at :: proc(fb: ^Fixed_Buffer, pos: int, b: u8) -> Fixed_Buffer_Error {
	return insert_slice_at(fb, pos, {b})
}

@(require_results)
insert_rune_at :: proc(fb: ^Fixed_Buffer, pos: int, r: rune) -> Fixed_Buffer_Error {
	bytes, width := utf8.encode_rune(r)
	return insert_slice_at(fb, pos, bytes[:width])
}

@(require_results)
insert_string_at :: proc(fb: ^Fixed_Buffer, pos: int, str: string) -> Fixed_Buffer_Error {
	return insert_slice_at(fb, pos, transmute([]u8)str)
}

delete_range :: proc(fb: ^Fixed_Buffer, pos: int, count: int) {
	if pos >= 0 && pos < fb.len && count > 0 {
		valid_len := fb.len - pos
		// Clamp count so we don't delete past the end
		actual_count := min(count, valid_len)
		copy(fb.buf[pos:], fb.buf[pos + actual_count:fb.len])
		fb.len -= actual_count
	}
}

clear :: proc(fb: ^Fixed_Buffer) {
	fb.len = 0
}

@(require_results)
get_byte_at :: proc(fb: Fixed_Buffer, pos: int) -> (u8, bool) {
	if pos < 0 || pos >= fb.len {
		return 0, false
	}
	return fb.buf[pos], true
}

@(require_results)
peek_rune_at :: proc(fb: Fixed_Buffer, byte_idx: int) -> (rune, int) {
	if byte_idx < 0 || byte_idx >= fb.len {
		return utf8.RUNE_ERROR, 0
	}
	return utf8.decode_rune(fb.buf[byte_idx:fb.len])
}
