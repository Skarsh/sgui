package fixed_buffer

import "core:testing"

@(private = "file")
test_fixed_buffer :: proc(capacity: int, content: string) -> Fixed_Buffer {
	storage, alloc_err := make([]u8, capacity, context.temp_allocator)
	assert(alloc_err == .None)
	fb := Fixed_Buffer{}
	init_with_content(&fb, storage, transmute([]u8)content)
	return fb
}

@(private = "file")
check_insert :: proc(
	t: ^testing.T,
	capacity: int,
	initial_text: string,
	pos: int,
	val: $T,
	expected_err: Fixed_Buffer_Error,
	expected_text: string,
	loc := #caller_location,
) {
	fb := test_fixed_buffer(capacity, initial_text)
	err := insert_at(&fb, pos, val)
	testing.expectf(
		t,
		err == expected_err,
		"capacity %v: inserting %v at %v into %q: expected error %v, got %v",
		capacity,
		val,
		pos,
		initial_text,
		expected_err,
		err,
		loc = loc,
	)

	actual_text := get_text(fb)
	testing.expectf(
		t,
		actual_text == expected_text,
		"capacity %v: inserting %v at %v into %q: expected %q, got %q",
		capacity,
		val,
		pos,
		initial_text,
		expected_text,
		actual_text,
		loc = loc,
	)
}

@(private = "file")
check_delete :: proc(
	t: ^testing.T,
	initial_text: string,
	pos: int,
	count: int,
	expected_text: string,
	loc := #caller_location,
) {
	fb := test_fixed_buffer(16, initial_text)
	delete_range(&fb, pos, count)
	actual_text := get_text(fb)
	testing.expectf(
		t,
		actual_text == expected_text,
		"deleting %v bytes at %v from %q: expected %q, got %q",
		count,
		pos,
		initial_text,
		expected_text,
		actual_text,
		loc = loc,
	)
}

check_get_byte :: proc(
	t: ^testing.T,
	initial_text: string,
	pos: int,
	expected_byte: u8,
	expected_ok: bool,
	loc := #caller_location,
) {
	fb := test_fixed_buffer(16, initial_text)
	actual_byte, actual_ok := get_byte_at(fb, pos)
	testing.expectf(
		t,
		actual_byte == expected_byte && actual_ok == expected_ok,
		"byte at %v in %q: expected (%v, %v), got (%v, %v)",
		pos,
		initial_text,
		expected_byte,
		expected_ok,
		actual_byte,
		actual_ok,
		loc = loc,
	)
}

@(test)
test_insert :: proc(t: ^testing.T) {
	check_insert(t, 16, "", 0, "hello", .None, "hello")
	check_insert(t, 16, "hello", 5, " world", .None, "hello world")
	check_insert(t, 16, "hello world", 5, ",", .None, "hello, world")
	check_insert(t, 8, "ac", 1, u8('b'), .None, "abc")
	check_insert(t, 4, "ab", 2, "cd", .None, "abcd")
	check_insert(t, 16, "H", 1, "é世", .None, "Hé世")
	check_insert(t, 4, "abc", 3, "é", .Buffer_Full, "abc")
	check_insert(t, 8, "abc", 1, "", .None, "abc")
}

@(test)
test_delete_range :: proc(t: ^testing.T) {
	check_delete(t, "hello world", 5, 6, "hello")
	check_delete(t, "hello", 0, 2, "llo")

	// Out of range is no-op
	check_delete(t, "abc", -1, 1, "abc")
	check_delete(t, "abc", 3, 1, "abc")
	// Zero count
	check_delete(t, "abc", 1, 0, "abc")

	// Count clamps to the end
	check_delete(t, "abc", 0, 4, "")
	check_delete(t, "abc", 2, 2, "ab")
}

@(test)
test_get_byte_at :: proc(t: ^testing.T) {
	check_get_byte(t, "abc", 0, 'a', true)
	check_get_byte(t, "abc", 2, 'c', true)

	// Out of range
	check_get_byte(t, "abc", 3, 0, false)
	check_get_byte(t, "abc", -1, 0, false)
	check_get_byte(t, "", 0, 0, false)
}

@(test)
test_clear :: proc(t: ^testing.T) {
	N :: 8
	fb := test_fixed_buffer(N, "hello")
	clear(&fb)
	actual_text := get_text(fb)

	testing.expect_value(t, actual_text, "")
	testing.expect_value(t, fb.len, 0)
	testing.expect_value(t, capacity(fb), N)
	testing.expect_value(t, remaining(fb), N)
}
