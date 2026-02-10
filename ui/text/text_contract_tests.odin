package text

import "core:testing"

import gap_buffer "../../gap_buffer"

@(test)
test_text_buffer_delete_range_removes_middle_bytes :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcXYZdef", context.allocator)
	defer text_buffer_deinit(&buf)

	text_buffer_delete_range(&buf, 3, 3)

	actual := gap_buffer.get_text(buf.gb)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
}
