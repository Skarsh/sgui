package text

import "core:testing"

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
