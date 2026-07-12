package fixed_buffer

import "core:testing"
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


// ----------------- Tests ----------------- //

// Test only helper to check insert error
@(private = "file")
insert_ok :: proc(t: ^testing.T, fb: ^Fixed_Buffer, pos: int, val: $T, loc := #caller_location) {
	fb_err := insert_at(fb, pos, val)
	testing.expect_value(t, fb_err, Fixed_Buffer_Error.None, loc)
}

@(test)
test_init :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	testing.expect_value(t, fb.len, 0)
	testing.expect_value(t, capacity(fb), N)
}

@(test)
test_init_with_content :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	content := "hello"
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)content)
	testing.expect_value(t, fb.len, len(content))
	testing.expect_value(t, capacity(fb), N)
	testing.expect_value(t, contents_string(fb), "hello")
}

@(test)
test_insert_slice :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	insert_ok(t, &fb, 0, transmute([]u8)string("hello"))
	testing.expect_value(t, contents_string(fb), "hello")

	insert_ok(t, &fb, 5, transmute([]u8)string(" world"))
	testing.expect_value(t, contents_string(fb), "hello world")

	insert_ok(t, &fb, 5, transmute([]u8)string(","))
	testing.expect_value(t, contents_string(fb), "hello, world")
}

@(test)
test_insert_byte_at :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("ac"))

	insert_ok(t, &fb, 1, 'b')
	testing.expect_value(t, contents_string(fb), "abc")
}

@(test)
test_insert_exact :: proc(t: ^testing.T) {
	N :: 4
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("ab"))

	// remaining = 2, inserting exactly 2 bytes must succeed
	insert_ok(t, &fb, 2, "cd")
	testing.expect_value(t, contents_string(fb), "abcd")
	testing.expect_value(t, remaining(fb), 0)
}

@(test)
test_insert_negative_pos :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	testing.expect_assert(t, "pos must be non-negative")
	err := insert_at(&fb, -1, transmute([]u8)string("x"))
	testing.expect_value(t, err, Fixed_Buffer_Error.None)
	testing.fail_now(t, "expected assert did not fire")
}

@(test)
test_insert_pos_past_len :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	// fb.len == 0, so pos 1 is past the contents
	testing.expect_assert(t, "pos must be within the buffer contents")
	err := insert_at(&fb, 1, transmute([]u8)string("x"))
	testing.expect_value(t, err, Fixed_Buffer_Error.None)
	testing.fail_now(t, "expected assert did not fire")
}

@(test)
test_insert_rune_at :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	insert_ok(t, &fb, 0, 'H')
	testing.expect_value(t, contents_string(fb), "H")

	// Multi-byte rune
	insert_ok(t, &fb, 1, 'é')
	testing.expect_value(t, fb.len, 3) // 1 + 2 bytes
	testing.expect_value(t, contents_string(fb), "Hé")

	// 3-byte rune
	insert_ok(t, &fb, 3, '世')
	testing.expect_value(t, fb.len, 6) // 1 + 2 + 3
	testing.expect_value(t, contents_string(fb), "Hé世")
}

@(test)
test_insert_rune_overflow :: proc(t: ^testing.T) {
	N :: 4
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))

	// 'é' is 2 bytes, only 1 byte remaining
	err := insert_rune_at(&fb, 3, 'é')
	testing.expect_value(t, err, Fixed_Buffer_Error.Buffer_Full)
	testing.expect_value(t, fb.len, 3)
	testing.expect_value(t, remaining(fb), 1)
}

@(test)
test_insert_string_at :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := Fixed_Buffer {
		buf = backing[:],
	}

	insert_ok(t, &fb, 0, "hello")
	testing.expect_value(t, contents_string(fb), "hello")

	insert_ok(t, &fb, 5, " world")
	testing.expect_value(t, contents_string(fb), "hello world")

	insert_ok(t, &fb, 5, ",")
	testing.expect_value(t, contents_string(fb), "hello, world")
}

@(test)
test_insert_empty_is_noop :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))

	// Empty string in the middle
	insert_ok(t, &fb, 1, "")
	testing.expect_value(t, contents_string(fb), "abc")
	testing.expect_value(t, fb.len, 3)

	// Empty slice in the middle
	empty: []u8
	insert_ok(t, &fb, 1, empty)
	testing.expect_value(t, contents_string(fb), "abc")
	testing.expect_value(t, fb.len, 3)
}

@(test)
test_delete :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("hello world"))

	delete_range(&fb, 5, 6)
	testing.expect_value(t, contents_string(fb), "hello")

	delete_range(&fb, 0, 2)
	testing.expect_value(t, contents_string(fb), "llo")
}

@(test)
test_delete_out_of_range_is_noop :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}

	// Negative pos
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))
	delete_range(&fb, -1, 1)
	testing.expect_value(t, contents_string(fb), "abc")
	testing.expect_value(t, fb.len, 3)

	// pos at the very end, nothing left to delete
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))
	delete_range(&fb, 3, 1)
	testing.expect_value(t, contents_string(fb), "abc")
	testing.expect_value(t, fb.len, 3)

	// Zero count
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))
	delete_range(&fb, 1, 0)
	testing.expect_value(t, contents_string(fb), "abc")
	testing.expect_value(t, fb.len, 3)
}

@(test)
test_delete_count_clamps_to_end :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}

	// Count past the end from 0 pos deletes everything
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))
	delete_range(&fb, 0, 4)
	testing.expect_value(t, contents_string(fb), "")
	testing.expect_value(t, fb.len, 0)

	// Count past the end from a pos inside the buffer deletes
	// only what's left after pos
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))
	delete_range(&fb, 2, 2)
	testing.expect_value(t, contents_string(fb), "ab")
	testing.expect_value(t, fb.len, 2)
}

@(test)
test_clear :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("hello"))

	clear(&fb)
	testing.expect_value(t, fb.len, 0)
	testing.expect_value(t, capacity(fb), N)
	testing.expect_value(t, remaining(fb), N)
}

@(test)
test_byte_at :: proc(t: ^testing.T) {
	N :: 8
	backing: [N]u8
	fb := Fixed_Buffer{}
	init_with_content(&fb, backing[:], transmute([]u8)string("abc"))

	b, ok := get_byte_at(fb, 0)
	testing.expect(t, ok)
	testing.expect_value(t, b, 'a')

	b, ok = get_byte_at(fb, 2)
	testing.expect(t, ok)
	testing.expect_value(t, b, 'c')

	_, ok = get_byte_at(fb, 3)
	testing.expect(t, !ok)

	_, ok = get_byte_at(fb, -1)
	testing.expect(t, !ok)
}
