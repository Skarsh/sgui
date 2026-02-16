package text

import "core:testing"

@(test)
test_text_buffer_len_counts_runes :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("a©", context.allocator)
	defer text_buffer_deinit(&buf)

	testing.expect_value(t, text_buffer_rune_len(buf), 2)
}

@(test)
test_text_buffer_insert_at_start :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("World", context.allocator)
	defer text_buffer_deinit(&buf)

	text_buffer_insert_at(&buf, 0, "Hello ")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
	testing.expect_value(t, text_buffer_rune_len(buf), 11)
}

@(test)
test_text_buffer_insert_at_end :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("Hello", context.allocator)
	defer text_buffer_deinit(&buf)

	len_runes := text_buffer_rune_len(buf)
	text_buffer_insert_at(&buf, len_runes, " World")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
}

@(test)
test_text_buffer_insert_utf8_mid_insertion :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("Hi!", context.allocator)
	defer text_buffer_deinit(&buf)

	// Insert '世' (3 bytes) at rune index 2 (before '!')
	text_buffer_insert_at(&buf, 2, "世")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "Hi世!")

	// Verify counts
	// Runes: H, i, 世, ! = 4
	testing.expect_value(t, text_buffer_rune_len(buf), 4)

	// Bytes: 1 + 1 + 3 + 1 = 6
	testing.expect_value(t, text_buffer_byte_len(buf), 6)
}

@(test)
test_text_buffer_insert_into_existing_utf8 :: proc(t: ^testing.T) {
	// Setup: "A©B"
	// 'A' (1 byte), '©' (2 bytes), 'B' (1 byte)
	// Rune indices: 0->A, 1->©, 2->B
	buf := text_buffer_init_with_content("A©B", context.allocator)
	defer text_buffer_deinit(&buf)

	// Insert at rune index 2 (Between © and B)
	// We insert "★" (3 bytes)
	text_buffer_insert_at(&buf, 2, "★")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "A©★B")

	// Bytes: 1(A) + 2(©) + 3(★) + 1(B) = 7
	testing.expect_value(t, text_buffer_byte_len(buf), 7)
}


@(test)
test_text_buffer_insert_empty_string_is_safe :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("ABC", context.allocator)
	defer text_buffer_deinit(&buf)

	start_runes := text_buffer_rune_len(buf)
	start_bytes := text_buffer_byte_len(buf)

	// Insert empty string in middle
	text_buffer_insert_at(&buf, 1, "")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "ABC")
	testing.expect_value(t, text_buffer_rune_len(buf), start_runes)
	testing.expect_value(t, text_buffer_byte_len(buf), start_bytes)
}

@(test)
test_text_buffer_insert_out_of_bounds_high_clamps_to_end :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("Start", context.allocator)
	defer text_buffer_deinit(&buf)

	// Try to insert at rune index 100, which is way past "Start" (len 5)
	// Expectation: Appends to the end
	text_buffer_insert_at(&buf, 100, "End")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "StartEnd")
}

@(test)
test_text_buffer_insert_negative_index_clamps_to_start :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("World", context.allocator)
	defer text_buffer_deinit(&buf)

	// Try to insert at -5
	// Expectation: Prepends at 0
	text_buffer_insert_at(&buf, -5, "Hello ")

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
}

@(test)
test_text_buffer_delete_range_removes_middle_runes :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcXYZdef", context.allocator)
	defer text_buffer_deinit(&buf)

	text_buffer_delete_range(&buf, 3, 3)

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
}

@(test)
test_text_buffer_delete_range_utf8_correctness :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("Héllo", context.allocator)
	defer text_buffer_deinit(&buf)

	text_buffer_delete_range(&buf, 1, 1)

	actual := text_buffer_text(buf)
	defer delete(actual)

	// Should be "Hllo"
	testing.expect_value(t, actual, "Hllo")

	// Internal byte check: Should be 4 bytes left
	testing.expect_value(t, text_buffer_byte_len(buf), 4)
}

@(test)
test_text_buffer_delete_range_count_zero_is_no_op :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	before_len := text_buffer_byte_len(buf)

	text_buffer_delete_range(&buf, 2, 0)

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, text_buffer_byte_len(buf), before_len)
}

@(test)
test_text_buffer_delete_range_out_of_range_position_is_no_op :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	before_len := text_buffer_byte_len(buf)

	// Negative index
	text_buffer_delete_range(&buf, -1, 2)
	// Exact end index (valid for insert, invalid for delete range)
	text_buffer_delete_range(&buf, 6, 2)
	// Way past end
	text_buffer_delete_range(&buf, 7, 2)

	actual := text_buffer_text(buf)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, text_buffer_byte_len(buf), before_len)
}

@(test)
test_text_buffer_delete_range_count_clamps_to_end :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	// Start at rune 4 ('e'), try to delete 999 runes
	text_buffer_delete_range(&buf, 4, 999)

	actual := text_buffer_text(buf)
	defer delete(actual)

	// Should remove 'e' and 'f'
	testing.expect_value(t, actual, "abcd")

	// Remaining bytes: 4
	testing.expect_value(t, text_buffer_byte_len(buf), 4)
}

@(test)
text_text_buffer_next_word_rune_pos :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("ab cd", context.allocator)
	defer text_buffer_deinit(&buf)

	next_pos := text_buffer_next_word_rune_pos(buf, 0)

	testing.expect_value(t, next_pos, 3)
}

@(test)
test_text_buffer_next_word_rune_pos_gap_in_middle :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("ab cd ef", context.allocator)
	defer text_buffer_deinit(&buf)

	// Move the internal gap to the middle without changing content.
	text_buffer_insert_at(&buf, 2, "")

	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 0), 3)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 1), 3)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 2), 3)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 3), 6)
}

@(test)
test_text_buffer_next_word_rune_pos_utf8_and_unicode_whitespace :: proc(t: ^testing.T) {
	// "hé<NBSP><SPACE>世界"
	buf := text_buffer_init_with_content("hé  世界", context.allocator)
	defer text_buffer_deinit(&buf)

	// h, é, NBSP, SPACE, 世, 界
	testing.expect_value(t, text_buffer_rune_len(buf), 6)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 0), 4)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 1), 4)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 2), 4)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 3), 4)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 4), 6)
}

@(test)
test_text_buffer_next_word_rune_pos_clamps_input_position :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("ab cd", context.allocator)
	defer text_buffer_deinit(&buf)

	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, -100), 3)
	testing.expect_value(t, text_buffer_next_word_rune_pos(buf, 999), text_buffer_rune_len(buf))
}
