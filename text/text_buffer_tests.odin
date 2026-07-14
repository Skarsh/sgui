package text

import "core:testing"

// "hé<NBSP><SPACE>世界". The NBSP is written as an escape so that it survives
// editing tools that normalize unicode, it is invisible but has to stay a
// 2 byte non-space.
// h = 1 byte, é = 2 bytes, NBSP = 2 bytes, SPACE = 1, 世 = 3 bytes, 界 = 3 bytes
@(private = "file")
UTF8_SAMPLE :: "hé\u00a0 世界"
#assert(len(UTF8_SAMPLE) == 12)

@(test)
test_text_buffer_insert_clamps_position :: proc(t: ^testing.T) {
	// Past the end appends
	check_insert(t, "Start", 100, "End", "StartEnd")

	// Negative prepends
	check_insert(t, "World", -5, "Hello ", "Hello World")
	check_insert(t, "World", -999, "Hello ", "Hello World")

	// In range positions are untouched by the clamp
	check_insert(t, "bc", 0, "a", "abc")
	check_insert(t, "ab", 2, "c", "abc")
}

@(test)
test_text_buffer_next_word_byte_pos :: proc(t: ^testing.T) {
	check_next_word(t, "ab cd", 0, 3)
	check_next_word(t, "ab cd", 1, 3)

	// Input position is clamped
	check_next_word(t, "ab cd", -100, 3)
	check_next_word(t, "ab cd", 999, 5)

	// The NBSP is a 2 byte non-space, so "hé<NBSP>" is one 5 byte word and
	// the next word starts after the ASCII space at byte 6.
	check_next_word(t, UTF8_SAMPLE, 0, 6)
	check_next_word(t, UTF8_SAMPLE, 1, 6)
	check_next_word(t, UTF8_SAMPLE, 3, 6)
	check_next_word(t, UTF8_SAMPLE, 5, 6)
}

@(test)
test_text_buffer_prev_word_byte_pos :: proc(t: ^testing.T) {
	check_prev_word(t, "ab cd ef", 8, 6)
	check_prev_word(t, "ab cd ef", 7, 6)
	check_prev_word(t, "ab cd ef", 6, 3)
	check_prev_word(t, "ab cd ef", 3, 0)

	// Input position is clamped
	check_prev_word(t, "ab cd", -100, 0)
	check_prev_word(t, "ab cd", 999, 3)

	// See UTF8_SAMPLE for the byte layout
	check_prev_word(t, UTF8_SAMPLE, 12, 6)
	check_prev_word(t, UTF8_SAMPLE, 9, 6)
	check_prev_word(t, UTF8_SAMPLE, 6, 0)
	check_prev_word(t, UTF8_SAMPLE, 4, 0)
	check_prev_word(t, UTF8_SAMPLE, 2, 0)
}
