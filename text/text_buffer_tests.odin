package text

import "core:mem"
import "core:testing"

import "../gap_buffer"
import "fixed_buffer"

@(test)
test_text_buffer_len_counts_runes :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "a©")

	testing.expect_value(t, text_buffer_byte_length(tb), 3)
}

@(test)
test_text_buffer_insert_at_start :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "World")
	text_buffer_insert_ok(t, &tb, 0, "Hello ")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
	testing.expect_value(t, text_buffer_byte_length(tb), 11)
}

@(test)
test_text_buffer_insert_at_end :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "Hello")

	len_bytes := text_buffer_byte_length(tb)
	text_buffer_insert_ok(t, &tb, len_bytes, " World")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
	testing.expect_value(t, text_buffer_byte_length(tb), 11)
}

@(test)
test_text_buffer_insert_utf8_mid_insertion :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "Hi!")

	// Insert '世' (3 bytes) at byte index 2 (before '!')
	text_buffer_insert_ok(t, &tb, 2, "世")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "Hi世!")

	// Bytes: H = 1 + i = 1 + 世 = 3 + ! = 1 = 6
	testing.expect_value(t, text_buffer_byte_length(tb), 6)
}

@(test)
test_text_buffer_insert_into_existing_utf8 :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	// 'A' = 1 byte, '©' = 2 bytes, 'B' = 1 byte
	text_buffer_insert_ok(t, &tb, 0, "A©B")

	// We insert "★" = 3 bytes between A '©' and 'B', i.e. byte index 3
	text_buffer_insert_ok(t, &tb, 3, "★")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "A©★B")

	// Bytes: 1(A) + 2(©) + 3(★) + 1(B) = 7
	testing.expect_value(t, text_buffer_byte_length(tb), 7)
}


@(test)
test_text_buffer_insert_empty_string_is_safe :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "ABC")

	start_bytes := text_buffer_byte_length(tb)

	// Insert empty string in middle
	text_buffer_insert_ok(t, &tb, 1, "")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "ABC")
	testing.expect_value(t, text_buffer_byte_length(tb), start_bytes)
}

@(test)
test_text_buffer_insert_out_of_bounds_high_clamps_to_end :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "Start")

	// Try to insert at byte index 100, which is way past "Start" (len 5)
	// Expectation: Appends to the end
	text_buffer_insert_ok(t, &tb, 100, "End")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "StartEnd")
}

@(test)
test_text_buffer_insert_negative_index_clamps_to_start :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "World")

	// Try to insert at -5
	// Expectation: Prepends at 0
	text_buffer_insert_ok(t, &tb, -5, "Hello ")

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "Hello World")
}

@(test)
test_text_buffer_delete_range_removes_middle_runes :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "abcXYZdef")

	text_buffer_delete_range(&tb, 3, 3)

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
}

@(test)
test_text_buffer_delete_range_utf8_correctness :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "Héllo")

	// é is 2 bytes
	text_buffer_delete_range(&tb, 1, 2)

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	// Should be "Hllo"
	testing.expect_value(t, actual, "Hllo")

	// Internal byte check: Should be 4 bytes left
	testing.expect_value(t, text_buffer_byte_length(tb), 4)
}

@(test)
test_text_buffer_delete_range_count_zero_is_no_op :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "abcdef")

	before_len := text_buffer_byte_length(tb)

	text_buffer_delete_range(&tb, 2, 0)

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, text_buffer_byte_length(tb), before_len)
}

@(test)
test_text_buffer_delete_range_out_of_range_position_is_no_op :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "abcdef")

	before_len := text_buffer_byte_length(tb)

	// Negative index
	text_buffer_delete_range(&tb, -1, 2)
	// Exact end index (valid for insert, invalid for delete range)
	text_buffer_delete_range(&tb, 6, 2)
	// Way past end
	text_buffer_delete_range(&tb, 7, 2)

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, text_buffer_byte_length(tb), before_len)
}

@(test)
test_text_buffer_delete_range_count_clamps_to_end :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "abcdef")

	// Start at rune 4 ('e'), try to delete 999 runes
	text_buffer_delete_range(&tb, 4, 999)

	actual, text_alloc_err := text_buffer_text(tb, context.allocator)
	assert(text_alloc_err == .None)
	defer delete(actual)

	// Should remove 'e' and 'f'
	testing.expect_value(t, actual, "abcd")

	// Remaining bytes: 4
	testing.expect_value(t, text_buffer_byte_length(tb), 4)
}

@(test)
text_text_buffer_next_word_byte_pos :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "ab cd")

	next_pos := text_buffer_next_word_byte_pos(tb, 0)

	testing.expect_value(t, next_pos, 3)
}

@(test)
test_text_buffer_next_word_rune_pos_gap_in_middle :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "ab cd ef")

	// Move the internal "caret" to the middle without changing content.
	text_buffer_insert_ok(t, &tb, 2, "")

	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 0), 3)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 1), 3)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 2), 3)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 3), 6)
}

@(test)
test_text_buffer_next_word_rune_pos_utf8_and_unicode_whitespace :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	// "hé<NBSP><SPACE>世界"
	text_buffer_insert_ok(t, &tb, 0, "hé  世界")

	// h = 1 byte, é = 2 bytes, NBSP = 2 bytes, SPACE = 1, 世 = 3 bytes, 界 = 3 bytes
	// 1 + 2 + 2 + 1 + 3 + 3 = 12
	testing.expect_value(t, text_buffer_byte_length(tb), 12)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 0), 6)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 1), 6)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 3), 6)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 5), 6)
}

@(test)
test_text_buffer_next_word_rune_pos_clamps_input_position :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)
	text_buffer_insert_ok(t, &tb, 0, "ab cd")

	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, -100), 3)
	testing.expect_value(t, text_buffer_next_word_byte_pos(tb, 999), text_buffer_byte_length(tb))
}

@(test)
test_text_buffer_prev_word_rune_pos_basic :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)
	text_buffer_insert_ok(t, &tb, 0, "ab cd ef")

	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 8), 6)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 7), 6)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 6), 3)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 3), 0)
}

@(test)
test_text_buffer_prev_word_rune_pos_utf8_and_unicode_whitespace :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	// "hé<NBSP><SPACE>世界"
	text_buffer_insert_ok(t, &tb, 0, "hé  世界")

	// h = 1 byte, é = 2 bytes, NBSP = 2 bytes, SPACE = 1, 世 = 3 bytes, 界 = 3 bytes
	// 1 + 2 + 2 + 1 + 3 + 3 = 12
	testing.expect_value(t, text_buffer_byte_length(tb), 12)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 12), 6)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 9), 6)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 6), 0)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 4), 0)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 2), 0)
}

@(test)
test_text_buffer_prev_word_rune_pos_clamps_input_position :: proc(t: ^testing.T) {
	gb := gap_buffer.Gap_Buffer{}
	gb_alloc_err := gap_buffer.init_gap_buffer(
		&gb,
		gap_buffer.DEFAULT_GAP_BUFFER_SIZE,
		context.allocator,
	)
	assert(gb_alloc_err == .None)
	tb := Text_Buffer {
		buf = gb,
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "ab cd")

	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, -100), 0)
	testing.expect_value(t, text_buffer_prev_word_byte_pos(tb, 999), 3)
}

// Fixed buffer tests
@(test)
test_text_buffer_delete_range_count_clamps_to_end_fixed :: proc(t: ^testing.T) {
	storage: [64]u8
	tb := Text_Buffer {
		buf = fixed_buffer.Fixed_Buffer{buf = storage[:], len = 0},
	}
	defer text_buffer_deinit(&tb)

	text_buffer_insert_ok(t, &tb, 0, "abcdef")
	// Should delete "ef" from the end, making the
	// resulting buffer contain "abcd"
	text_buffer_delete_range(&tb, 4, 999)

	// NOTE(Thomas): The Fixed_Buffer path never allocates, it returns a view into
	// storage, so the allocator is unused and actual is only valid while tb is alive.
	actual, text_alloc_err := text_buffer_text(tb, mem.nil_allocator())
	assert(text_alloc_err == .None)

	testing.expect_value(t, text_buffer_byte_length(tb), 4)
	// Should remove 'e' and 'f'
	testing.expect_value(t, actual, "abcd")
}
