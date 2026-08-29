package text

import "core:testing"

@(test)
test_text_buffer_replace_range :: proc(t: ^testing.T) {
	// Empty ranges insert at the beginning and end.
	check_replace(t, "World", 0, 0, "Hello ", "Hello World")
	check_replace(t, "Start", 5, 5, "End", "StartEnd")

	// Non-empty ranges replace or delete their contents.
	check_replace(t, "abcdef", 1, 4, "XYZ", "aXYZef")
	check_replace(t, "abcdef", 1, 4, "", "aef")

	// Replacing the complete range can produce an empty buffer.
	check_replace(t, "abc", 0, 3, "", "")
}
