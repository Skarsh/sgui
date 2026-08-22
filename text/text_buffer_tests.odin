package text

import "core:testing"

@(test)
test_text_buffer_insert_clamps_position :: proc(t: ^testing.T) {
	// Past the end appends
	check_insert(t, TEST_BUFFER_CAP, "Start", 100, "End", "StartEnd")

	// Negative prepends
	check_insert(t, TEST_BUFFER_CAP, "World", -5, "Hello ", "Hello World")
	check_insert(t, TEST_BUFFER_CAP, "World", -999, "Hello ", "Hello World")

	// In range positions are untouched by the clamp
	check_insert(t, TEST_BUFFER_CAP, "bc", 0, "a", "abc")
	check_insert(t, TEST_BUFFER_CAP, "ab", 2, "c", "abc")
}
