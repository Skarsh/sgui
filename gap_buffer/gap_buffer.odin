package gap_buffer

import "core:mem"
import "core:testing"
import "core:unicode/utf8"

Gap_Buffer :: struct {
	buf:       []u8,
	start:     int,
	end:       int,
	allocator: mem.Allocator,
}

make_gap_buffer :: proc(size: int, allocator := context.allocator) -> Gap_Buffer {
	gb := Gap_Buffer {
		buf       = make([]u8, size, allocator),
		start     = 0,
		end       = size,
		allocator = allocator,
	}
	return gb
}

deinit :: proc(gb: ^Gap_Buffer) {
	delete(gb.buf, gb.allocator)
	gb^ = {}
}

// NOTE - This allocates using the passed in allocator,
// for rendering and serach you might want to use the
// Gap_Buffer_Iterator instead, which won't allocate.
get_text :: proc(gb: Gap_Buffer) -> string {
	res := make([]u8, length(gb), gb.allocator)

	// copy left
	copy(res[:gb.start], gb.buf[:gb.start])

	// copy right
	copy(res[gb.start:], gb.buf[gb.end:])

	return string(res)
}

insert :: proc {
	insert_byte,
	insert_rune,
	insert_slice,
	insert_string,
}

insert_byte :: proc(gb: ^Gap_Buffer, pos: int, ch: u8) {
	if pos >= 0 && pos <= length(gb^) {
		ensure_space(gb, 1)
		shift_gap_to(gb, pos)
		gb.buf[gb.start] = ch
		gb.start += 1
	}
}

insert_rune :: proc(gb: ^Gap_Buffer, pos: int, r: rune) {
	if pos >= 0 && pos <= length(gb^) {
		bytes, width := utf8.encode_rune(r)
		insert_slice(gb, pos, bytes[:width])
	}
}

insert_slice :: proc(gb: ^Gap_Buffer, pos: int, slice: []u8) {
	if pos >= 0 && pos <= length(gb^) {
		ensure_space(gb, len(slice))
		shift_gap_to(gb, pos)
		copy(gb.buf[gb.start:], slice)
		gb.start += len(slice)
	}
}

insert_string :: proc(gb: ^Gap_Buffer, pos: int, str: string) {
	if pos >= 0 && pos <= length(gb^) {
		insert_slice(gb, pos, transmute([]u8)str)
	}
}


delete_at :: proc(gb: ^Gap_Buffer, pos: int) {
	if pos >= 0 && pos < length(gb^) {
		shift_gap_to(gb, pos)
		gb.end += 1
	}
}

delete_range :: proc(gb: ^Gap_Buffer, pos: int, count: int) {
	valid_len := length(gb^)
	if (pos >= 0 && pos < length(gb^)) && count > 0 {

		// Clamp count so we don't delete past the end
		actual_count := min(count, valid_len - pos)

		// Move gap to start of deletion
		shift_gap_to(gb, pos)

		gb.end += actual_count
	}
}


length :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf) - (gb.end - gb.start)
}

capacity :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf)
}

gap_size :: proc(gb: Gap_Buffer) -> int {
	return gb.end - gb.start
}

// Helper procedure to get the left and right strings of the gap
@(private)
get_strings :: proc(gb: Gap_Buffer) -> (left: string, right: string) {
	left = string(gb.buf[0:gb.start])
	right = string(gb.buf[gb.end:])
	return
}

// Grows the buffer when out of space
@(private)
grow :: proc(gb: ^Gap_Buffer, required: int) {
	current_len := len(gb.buf)
	new_cap := max(current_len * 2, current_len + required)

	// Amount how much bigger the buffer is getting
	amount_grown := new_cap - current_len

	new_buf := make([]u8, new_cap, gb.allocator)

	// Copy data before the gap
	copy(new_buf[:gb.start], gb.buf[:gb.start])

	// Calculate new end
	new_end := gb.end + amount_grown

	// Copy right side
	copy(new_buf[new_end:], gb.buf[gb.end:])

	delete(gb.buf, gb.allocator)
	gb.buf = new_buf
	gb.end = new_end
}

// Helper to ensure we grow if we don't have enough space
@(private)
ensure_space :: proc(gb: ^Gap_Buffer, amount: int) {
	if gap_size(gb^) < amount {
		grow(gb, amount)
	}
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

Gap_Buffer_Iterator :: struct {
	gb:  Gap_Buffer,
	idx: int,
}

make_gap_buffer_iterator :: proc(gb: Gap_Buffer) -> Gap_Buffer_Iterator {
	return Gap_Buffer_Iterator{gb = gb, idx = 0}
}

gap_buffer_iterator_next :: proc(it: ^Gap_Buffer_Iterator) -> (u8, int, bool) {
	if it.idx >= length(it.gb) {
		return 0, it.idx, false
	}

	ch: u8
	if it.idx < it.gb.start {
		ch = it.gb.buf[it.idx]
	} else {
		ch = it.gb.buf[it.idx + gap_size(it.gb)]
	}

	curr_idx := it.idx
	it.idx += 1
	return ch, curr_idx, true
}

// ----------------- Tests ----------------- //

check_str :: proc(t: ^testing.T, gb: Gap_Buffer, expected: string, loc := #caller_location) {
	s := get_text(gb)
	defer delete(s)
	testing.expect_value(t, s, expected, loc)
}

@(test)
test_basic_insert :: proc(t: ^testing.T) {
	gb := make_gap_buffer(10)
	defer deinit(&gb)

	// Test 1: Append
	insert(&gb, 0, "Hello")
	check_str(t, gb, "Hello")

	// Test 2: Insert in middle (Moves gap)
	// Current "Hello", Pos: 1 -> "Hello"
	insert(&gb, 1, "i")
	check_str(t, gb, "Hiello")

	// Test 3: Insert at end
	insert(&gb, length(gb), "!")
	check_str(t, gb, "Hiello!")
}

@(test)
test_cursor_movement_logic :: proc(t: ^testing.T) {
	gb := make_gap_buffer(10)
	defer deinit(&gb)

	insert(&gb, 0, "ABC")
	// Buffer state: [A, B, C, gap, gap, gap, gap, gap, gap, gap]
	// Text: "ABC"
	// Gap Size: 7

	insert(&gb, 1, "X")
	// 1. Logic shifts gap to index 1 (between A and B).
	//    State: [A, gap, gap, gap, gap, gap, gap, gap, B, C]

	// 2. 'X' is written into the start of the gap.
	//    State: [A, X, gap, gap, gap, gap, gap, gap, B, C]

	check_str(t, gb, "AXBC")

	// Total chars: A, X, B, C = 4
	testing.expect_value(t, length(gb), 4)

	// Total capacity (10) - Total text (4) = Remaining Gap (6)
	testing.expect_value(t, gap_size(gb), 6)
}

@(test)
test_growing :: proc(t: ^testing.T) {
	// Start very small
	gb := make_gap_buffer(2)
	defer deinit(&gb)

	testing.expect_value(t, capacity(gb), 2)

	insert(&gb, 0, "A")
	insert(&gb, 1, "B")

	// Buffer is full (used 2, cap 2)
	testing.expect(t, gap_size(gb) == 0, "Gap should be empty")

	// This triggers grow()
	insert(&gb, 2, "C")

	check_str(t, gb, "ABC")
	testing.expect(t, capacity(gb) > 2, "Capacity should have grown")

	// Test inserting larger than current capacity
	long_str := "Defghijk"
	insert(&gb, 3, long_str)
	check_str(t, gb, "ABCDefghijk")
}

@(test)
test_deletion :: proc(t: ^testing.T) {
	gb := make_gap_buffer(20)
	defer deinit(&gb)

	insert(&gb, 0, "0123456789")

	// Delete at start
	delete_at(&gb, 0)
	check_str(t, gb, "123456789")

	// Delete '5' (in the middle)
	delete_at(&gb, 4)
	check_str(t, gb, "12346789")

	// Delete at '9' (at the end)
	len_now := length(gb)
	delete_at(&gb, len_now - 1)
	check_str(t, gb, "1234678")
}

@(test)
test_range_deletion :: proc(t: ^testing.T) {
	gb := make_gap_buffer(20)
	defer deinit(&gb)

	insert(&gb, 0, "Hello World")

	// Delete " World" (at index 5, length 6)
	delete_range(&gb, 5, 6)
	check_str(t, gb, "Hello")

	// Test deleting out of bounds
	// Hello!!!
	insert(&gb, 5, "!!!")

	// Trying to delete way past the end, should clamp to only
	// deleting the 3 that exists
	delete_range(&gb, 5, 100)
	check_str(t, gb, "Hello")
}

@(test)
test_rune_utf8 :: proc(t: ^testing.T) {
	gb := make_gap_buffer(20)
	defer deinit(&gb)

	insert(&gb, 0, "Hi")
	// Buffer: "Hi" (Length 2)

	// 1. Insert '世' at index 2
	// '世' is 3 bytes (0xE4, 0xB8, 0x96)
	insert(&gb, 2, '世')

	// Buffer should now be 2 + 3 = 5 bytes.
	testing.expect_value(t, length(gb), 5)

	// 2. Insert '界' AFTER '世'.
	// We must advance by the byte width of '世' (3 bytes).
	// Start pos (2) + Width (3) = 5.
	insert(&gb, 5, '界')

	// Buffer should now be 5 + 3 = 8 bytes.
	testing.expect_value(t, length(gb), 8)

	check_str(t, gb, "Hi世界")
}

@(test)
test_stress_random :: proc(t: ^testing.T) {
	// A small stress test moving the gap back and forth
	gb := make_gap_buffer(4)
	defer deinit(&gb)

	insert_byte(&gb, 0, 'A') // A
	insert(&gb, 0, "B") // BA
	insert_byte(&gb, 1, 'C') // BCA
	insert(&gb, 3, "D") // BCAD
	delete_at(&gb, 0) // CAD
	insert(&gb, 1, "E") // CEAD

	check_str(t, gb, "CEAD")
}

@(test)
test_iterator_empty :: proc(t: ^testing.T) {
	gb := make_gap_buffer(10)
	defer deinit(&gb)

	it := make_gap_buffer_iterator(gb)

	// Should be empty
	val, idx, ok := gap_buffer_iterator_next(&it)
	testing.expect_value(t, val, 0)
	testing.expect_value(t, idx, 0)
	testing.expect(t, !ok, "Iterator should return false or empty buffer")
}

@(test)
test_iterator_gap_in_the_middle :: proc(t: ^testing.T) {
	gb := make_gap_buffer(10)
	defer deinit(&gb)

	// Insert "AB"
	insert(&gb, 0, "A")
	insert(&gb, 1, "B")

	// Move gap to index 1 (Between A and B)
	// Memory: [A, gap, gap, ... , B]
	shift_gap_to(&gb, 1)

	it := make_gap_buffer_iterator(gb)

	// First char: 'A' at index 0
	val, idx, ok := gap_buffer_iterator_next(&it)
	testing.expect(t, ok, "Should have first element")
	testing.expect_value(t, idx, 0)
	testing.expect_value(t, val, 'A')

	// First char: 'B' at index 1
	val, idx, ok = gap_buffer_iterator_next(&it)
	testing.expect(t, ok, "Should have second element")
	testing.expect_value(t, idx, 1)
	testing.expect_value(t, val, 'B')

	val, idx, ok = gap_buffer_iterator_next(&it)
	testing.expect(t, !ok, "Should be done")
}

@(test)
test_iterator_matches_get_text :: proc(t: ^testing.T) {
	gb := make_gap_buffer(20)
	defer deinit(&gb)

	// Insert "Hello World" with gap in the word "World"
	insert(&gb, 0, "Hello World")
	// Gap inside "Wor...ld"
	shift_gap_to(&gb, 8)

	// Get the standard string (allocating)
	full_text := get_text(gb)
	defer delete(full_text)

	// Iterate (non-allocating)
	it := make_gap_buffer_iterator(gb)

	loop_count := 0
	for ch, i in gap_buffer_iterator_next(&it) {
		testing.expect_value(t, i, loop_count)

		testing.expect_value(t, ch, full_text[i])

		loop_count += 1
	}

	testing.expect_value(t, loop_count, len(full_text))
}

@(test)
test_iterator_utf8_bytes :: proc(t: ^testing.T) {
	gb := make_gap_buffer(10)
	defer deinit(&gb)

	// Insert '世' (3 bytes)
	insert(&gb, 0, '世')

	// Move gap to 0, moving '世' to the right of the gap
	// This is to make sure that the iterator will skip the gap
	shift_gap_to(&gb, 0)

	it := make_gap_buffer_iterator(gb)

	// We expect 3 individual bytes
	// 1st byte
	ch, i, ok := gap_buffer_iterator_next(&it)
	testing.expect(t, ok)
	testing.expect_value(t, ch, 0xE4)

	// 2nd byte
	ch, i, ok = gap_buffer_iterator_next(&it)
	testing.expect(t, ok)
	testing.expect_value(t, ch, 0xB8)

	// 3rd byte
	ch, i, ok = gap_buffer_iterator_next(&it)
	testing.expect(t, ok)
	testing.expect_value(t, ch, 0x96)

	_, _, ok = gap_buffer_iterator_next(&it)
	testing.expect(t, !ok)
}
