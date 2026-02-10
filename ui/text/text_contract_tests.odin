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

@(test)
test_text_buffer_delete_range_count_zero_is_no_op :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	before_len := gap_buffer.length(buf.gb)

	text_buffer_delete_range(&buf, 2, 0)

	actual := gap_buffer.get_text(buf.gb)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, gap_buffer.length(buf.gb), before_len)
}

@(test)
test_text_buffer_delete_range_out_of_range_position_is_no_op :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	before_len := gap_buffer.length(buf.gb)

	text_buffer_delete_range(&buf, -1, 2)
	text_buffer_delete_range(&buf, 6, 2)
	text_buffer_delete_range(&buf, 7, 2)

	actual := gap_buffer.get_text(buf.gb)
	defer delete(actual)

	testing.expect_value(t, actual, "abcdef")
	testing.expect_value(t, gap_buffer.length(buf.gb), before_len)
}

@(test)
test_text_buffer_delete_range_count_clamps_to_end :: proc(t: ^testing.T) {
	buf := text_buffer_init_with_content("abcdef", context.allocator)
	defer text_buffer_deinit(&buf)

	text_buffer_delete_range(&buf, 4, 999)

	actual := gap_buffer.get_text(buf.gb)
	defer delete(actual)

	testing.expect_value(t, actual, "abcd")
	testing.expect_value(t, gap_buffer.length(buf.gb), 4)
}
