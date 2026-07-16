package gap_buffer

import "core:testing"
import "core:unicode/utf8"

@(private = "file")
TEST_BUFFER_CAP :: 16

// Test only helper to make a Gap_Buffer with the given capacity and
// intialize with the provided text.
@(private = "file")
@(require_results)
test_gap_buffer :: proc(capacity: int, text: string) -> Gap_Buffer {
	gb := Gap_Buffer{}
	alloc_err := init_gap_buffer(&gb, capacity, context.temp_allocator)
	assert(alloc_err == .None)
	insert_err := insert_at(&gb, 0, text)
	assert(insert_err == .None)
	return gb
}

// Test only helper which checks that the buffer contents equal expected.
@(private = "file")
check_text :: proc(t: ^testing.T, gb: Gap_Buffer, expected: string, loc := #caller_location) {
	actual, text_err := get_text(gb, context.temp_allocator)
	assert(text_err == .None)
	testing.expectf(t, actual == expected, "expected %q, got %q", expected, actual, loc = loc)
}

// Test only helper which inserts and expects the insertion to succeed.
@(private = "file")
insert_ok :: proc(t: ^testing.T, gb: ^Gap_Buffer, pos: int, val: $T, loc := #caller_location) {
	insert_err := insert_at(gb, pos, val)
	testing.expectf(
		t,
		insert_err == .None,
		"inserting %v at %v: expected success, got %v",
		val,
		pos,
		insert_err,
		loc = loc,
	)
}

// Test only helper which checks that inserting text into an inital_text at given pos
// yields the expected text.
@(private = "file")
check_insert :: proc(
	t: ^testing.T,
	capacity: int,
	initial_text: string,
	pos: int,
	val: $T,
	expected_text: string,
	loc := #caller_location,
) {
	gb := test_gap_buffer(capacity, initial_text)
	defer deinit(&gb)

	insert_err := insert_at(&gb, pos, val)
	testing.expectf(
		t,
		insert_err == .None,
		"capacity %v, inserting %v at %v into %q: expected success, got %v",
		capacity,
		val,
		pos,
		initial_text,
		insert_err,
		loc = loc,
	)

	actual_text, text_err := get_text(gb, context.temp_allocator)
	assert(text_err == .None)
	testing.expectf(
		t,
		actual_text == expected_text,
		"capacity %v, inserting %v at %v into %q: expected %q, got %q",
		capacity,
		val,
		pos,
		initial_text,
		expected_text,
		actual_text,
		loc = loc,
	)
}

// Test only helper which checks that deleting a single byte at pos
// from initial_text yields the expected text.
@(private = "file")
check_delete_at :: proc(
	t: ^testing.T,
	initial_text: string,
	pos: int,
	expected_text: string,
	loc := #caller_location,
) {
	gb := test_gap_buffer(TEST_BUFFER_CAP, initial_text)
	delete_at(&gb, pos)
	actual_text, text_err := get_text(gb, context.temp_allocator)
	assert(text_err == .None)
	testing.expectf(
		t,
		actual_text == expected_text,
		"deleting at %v from %q: expected %q, got %q",
		pos,
		initial_text,
		expected_text,
		actual_text,
		loc = loc,
	)
}

// Test only helper which checks that deleting count bytes at pos
// from initial_text yields the expected text.
@(private = "file")
check_delete_range :: proc(
	t: ^testing.T,
	initial_text: string,
	pos: int,
	count: int,
	expected_text: string,
	loc := #caller_location,
) {
	gb := test_gap_buffer(TEST_BUFFER_CAP, initial_text)
	delete_range(&gb, pos, count)

	actual_text, text_err := get_text(gb, context.temp_allocator)
	assert(text_err == .None)
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

// Test only helper which checks the byte and ok result of get_byte_at at pos.
@(private = "file")
check_get_byte :: proc(
	t: ^testing.T,
	initial_text: string,
	pos: int,
	expected_byte: u8,
	expected_ok: bool,
	loc := #caller_location,
) {
	gb := test_gap_buffer(TEST_BUFFER_CAP, initial_text)
	actual_byte, actual_ok := get_byte_at(gb, pos)
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

// Test only helper which checks the rune and width result of peek_rune_at at byte_idx.
@(private = "file")
check_peek_rune :: proc(
	t: ^testing.T,
	initial_text: string,
	byte_idx: int,
	expected_rune: rune,
	expected_width: int,
	loc := #caller_location,
) {
	gb := test_gap_buffer(TEST_BUFFER_CAP, initial_text)
	actual_rune, actual_width := peek_rune_at(gb, byte_idx)
	testing.expectf(
		t,
		actual_rune == expected_rune && actual_width == expected_width,
		"rune at byte %v in %q: expected (%v, %v), got (%v, %v)",
		byte_idx,
		initial_text,
		expected_rune,
		expected_width,
		actual_rune,
		actual_width,
		loc = loc,
	)
}

@(test)
test_insert :: proc(t: ^testing.T) {
	check_insert(t, 16, "", 0, "hello", "hello")
	check_insert(t, 16, "hello", 5, " world", "hello world")
	check_insert(t, 16, "hello world", 5, ",", "hello, world")
	check_insert(t, 16, "Hello", 1, "i", "Hiello")
	check_insert(t, 8, "ac", 1, u8('b'), "abc")
	check_insert(t, 16, "Hi", 2, '世', "Hi世")
	check_insert(t, 16, "Hi世", 5, '界', "Hi世界")
	check_insert(t, 16, "H", 1, "é世", "Hé世")

	// Empty inserts are no-ops
	check_insert(t, 16, "abc", 1, "", "abc")
	empty: []u8
	check_insert(t, 16, "abc", 1, empty, "abc")
}

@(test)
test_insert_grows_buffer :: proc(t: ^testing.T) {
	// Buffer starts full, inserting triggers a grow
	check_insert(t, 2, "ab", 2, "c", "abc")

	// Inserting more than the whole current capacity
	check_insert(t, 2, "ab", 2, "cdefghij", "abcdefghij")

	// Growing when inserting in the middle
	check_insert(t, 4, "abcd", 2, "XY", "abXYcd")
}

@(test)
test_delete_at :: proc(t: ^testing.T) {
	check_delete_at(t, "abc", 0, "bc")
	check_delete_at(t, "abc", 1, "ac")
	check_delete_at(t, "abc", 2, "ab")

	// Out of range is no-op
	check_delete_at(t, "abc", -1, "abc")
	check_delete_at(t, "abc", 3, "abc")
	check_delete_at(t, "", 0, "")
}

@(test)
test_delete_range :: proc(t: ^testing.T) {
	check_delete_range(t, "hello world", 5, 6, "hello")
	check_delete_range(t, "hello", 0, 2, "llo")

	// Out of range is no-op
	check_delete_range(t, "abc", -1, 1, "abc")
	check_delete_range(t, "abc", 3, 1, "abc")
	check_delete_range(t, "abc", 4, 1, "abc")

	// Zero count is no-op
	check_delete_range(t, "abc", 1, 0, "abc")

	// Count clamps to end
	check_delete_range(t, "abc", 0, 100, "")
	check_delete_range(t, "abc", 2, 2, "ab")
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
test_get_byte_at_matches_get_text_after_edits :: proc(t: ^testing.T) {
	gb := test_gap_buffer(4, "abc")
	insert_ok(t, &gb, 1, "x")
	delete_at(&gb, 2)
	insert_ok(t, &gb, 3, "d")

	full_text, text_err := get_text(gb, context.temp_allocator)
	assert(text_err == .None)
	check_text(t, gb, "axcd")

	for i in 0 ..< len(full_text) {
		actual_byte, actual_ok := get_byte_at(gb, i)
		testing.expect(t, actual_ok)
		testing.expect_value(t, actual_byte, full_text[i])
	}
}

@(test)
test_peek_rune_at :: proc(t: ^testing.T) {
	check_peek_rune(t, "Hé世", 0, 'H', 1)
	check_peek_rune(t, "Hé世", 1, 'é', 2)
	check_peek_rune(t, "Hé世", 3, '世', 3)

	// Past the end
	check_peek_rune(t, "abc", 3, utf8.RUNE_ERROR, 0)
}

@(test)
test_edit_sequence :: proc(t: ^testing.T) {
	// Interleaved inserts and deletes move the gap back and forth
	// and force a grow while the gap is in the middle.
	gb := test_gap_buffer(4, "")

	insert_ok(t, &gb, 0, 'A')
	check_text(t, gb, "A")

	insert_ok(t, &gb, 0, "B")
	check_text(t, gb, "BA")

	insert_ok(t, &gb, 1, 'C')
	check_text(t, gb, "BCA")

	insert_ok(t, &gb, 3, "D")
	check_text(t, gb, "BCAD")

	delete_at(&gb, 0)
	check_text(t, gb, "CAD")

	insert_ok(t, &gb, 1, "E")
	check_text(t, gb, "CEAD")

	insert_ok(t, &gb, 2, "fghij")
	check_text(t, gb, "CEfghijAD")
}
