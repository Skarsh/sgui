package text

import "core:testing"

import "../gap_buffer"

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
