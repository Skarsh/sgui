package text

import "core:strings"
import "core:testing"

import "../base"

MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10
MOCK_FONT_HANDLE :: 0

mock_measure_codepoint_proc :: proc(
	codepoint: rune,
	font_id: Font_Handle,
	user_data: rawptr,
) -> Codepoint_Metrics {
	width: f32 = 0
	left_bearing: f32 = 0
	if codepoint != '\n' {
		width = MOCK_CHAR_WIDTH
		left_bearing = MOCK_CHAR_WIDTH
	}
	return Codepoint_Metrics{width = width, left_bearing = left_bearing}
}

mock_measure_text_proc :: proc(
	text: string,
	font_id: Font_Handle,
	user_data: rawptr,
) -> Text_Metrics {
	width: f32 = f32(strings.rune_count(text) * MOCK_CHAR_WIDTH)
	line_height: f32 = MOCK_LINE_HEIGHT

	return Text_Metrics{width = width, line_height = line_height}
}

mock_text_measurement :: Text_Measurement {
	measure_text_proc      = mock_measure_text_proc,
	measure_codepoint_proc = mock_measure_codepoint_proc,
	font_user_data         = nil,
}

// Test only helper which checks that laying out text at the given width and
// wrap mode yields the expected size and rows
@(private = "file")
check_layout :: proc(
	t: ^testing.T,
	text: string,
	expected_size: base.Vec2,
	expected_rows: []Positioned_Row,
	max_width: f32,
	wrap_mode: Text_Wrap_Mode,
	loc := #caller_location,
) {
	layout, alloc_err := layout_text(
		text,
		max_width,
		MOCK_FONT_HANDLE,
		mock_text_measurement,
		context.temp_allocator,
		wrap_mode,
	)
	assert(alloc_err == .None)

	testing.expectf(
		t,
		layout.size == expected_size,
		"laying out %q at max_width %v and wrap_mode %v: expected size %v, got %v",
		text,
		max_width,
		wrap_mode,
		expected_size,
		layout.size,
		loc = loc,
	)

	testing.expectf(
		t,
		len(layout.rows) == len(expected_rows),
		"laying out %q at max_width %v with wrap_mode %v: expected %v rows, got %v",
		text,
		max_width,
		wrap_mode,
		len(expected_rows),
		len(layout.rows),
		loc = loc,
	)

	if len(layout.rows) == len(expected_rows) {
		for expected_row, i in expected_rows {
			testing.expectf(
				t,
				expected_row == layout.rows[i],
				"laying out %q at max_width %v with wrap_mode %v: expected row %v, got %v",
				text,
				max_width,
				wrap_mode,
				expected_row,
				layout.rows[i],
				loc = loc,
			)
		}
	}
}

@(test)
test_layout_text_no_wrapping_needed :: proc(t: ^testing.T) {
	// Empty input procudes no rows
	check_layout(
		t,
		text = "",
		expected_size = {0, 0},
		expected_rows = {},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// Single char fits on one row
	check_layout(
		t,
		text = "a",
		expected_size = {1 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {1 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 1},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// Text that exactly fills the max width stays on one row
	check_layout(
		t,
		text = "0123456789",
		expected_size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 10},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)
}

@(test)
test_layout_text_wraps :: proc(t: ^testing.T) {

	// TODO(Thomas): Think about correctness of this test. We overflow max size with 10
	// here because we're breaking on the whitespace between words, which is the only
	// linebreak candidate here, and the whitespace is included.
	// TODO(Thomas): The proper solution here is to separate content size and element size
	// somehow.
	check_layout(
		t,
		text = "strawberry accomplish",
		expected_size = {11 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {11 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 11},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {11, 21},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// Overflow in the middle of a word breaks back to previous whitespace
	check_layout(
		t,
		text = "one two three",
		expected_size = {8 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {8 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 8},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {8, 13},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// Wraps across three rows "abc def " | "ghi jkl " | "mno"
	check_layout(
		t,
		text = "abc def ghi jkl mno",
		expected_size = {8 * MOCK_CHAR_WIDTH, 3 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {8 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 8},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {8 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {8, 16},
			},
			Positioned_Row {
				pos = {0, 2 * MOCK_LINE_HEIGHT},
				size = {3 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {16, 19},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)
}

@(test)
test_layout_text_newlines :: proc(t: ^testing.T) {
	// A newline starts a new row even when both parts fit
	check_layout(
		t,
		text = "Hello\nWorld",
		expected_size = {5 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 6},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {6, 11},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// A single newline produces zero width row
	check_layout(
		t,
		text = "\n",
		expected_size = {0, MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row{pos = {0, 0}, size = {0, MOCK_LINE_HEIGHT}, glyph_range = {0, 1}},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)

	// Consecutive newlines procudes a zero width row in between
	check_layout(
		t,
		text = "a\n\nb",
		expected_size = {MOCK_CHAR_WIDTH, 3 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 2},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {0, MOCK_LINE_HEIGHT},
				glyph_range = {2, 3},
			},
			Positioned_Row {
				pos = {0, 2 * MOCK_LINE_HEIGHT},
				size = {MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {3, 4},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)
}

@(test)
test_layout_text_no_wrap_mode_overflows :: proc(t: ^testing.T) {
	// With .None Wrap_Mode a long word overflows the max width on a single row
	check_layout(
		t,
		text = "01234567890123456789",
		expected_size = {20 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {20 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 20},
			},
		},
		max_width = 100,
		wrap_mode = .None,
	)

}

@(test)
test_layout_text_truncate_mode_stops_at_max_width :: proc(t: ^testing.T) {
	check_layout(
		t,
		text = "01234567890123456789",
		expected_size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 20},
			},
		},
		max_width = 100,
		wrap_mode = .Truncate,
	)
}

@(test)
test_layout_text_wraps_mid_word_when_no_candidate :: proc(t: ^testing.T) {
	check_layout(
		t,
		text = "01234567890123456789",
		expected_size = {10 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		expected_rows = {
			Positioned_Row {
				pos = {0, 0},
				size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {0, 10},
			},
			Positioned_Row {
				pos = {0, MOCK_LINE_HEIGHT},
				size = {10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = {10, 20},
			},
		},
		max_width = 100,
		wrap_mode = .Wrap,
	)
}
