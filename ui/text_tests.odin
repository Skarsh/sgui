package ui

import "core:testing"


@(test)
test_fit_element_with_multiple_rows_of_text_and_pure_grow_sizing_elements :: proc(t: ^testing.T) {
	// A grow element inside a Fit row only takes the space that row has to give.
	check_layout(
		t,
		Element_Spec {
			id = "main",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 5,
				layout_direction = .Top_To_Bottom,
			},
			children = {
				{
					id = "row_1",
					style = {padding = padding_all(5), child_gap = 2},
					children = {
						{id = "text_1", text = "AAAA"},
						{
							id = "grow_1",
							style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
						},
					},
				},
				{
					id = "row_2",
					style = {padding = padding_all(5), child_gap = 2},
					children = {
						{id = "text_2", text = "AA"},
						{
							id = "grow_2",
							style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
						},
					},
				},
			},
		},
		Expected_Element {
			id = "main",
			pos = {0, 0},
			size = {72, 65},
			children = {
				{
					id = "row_1",
					pos = {10, 10},
					size = {52, 20},
					children = {
						{id = "text_1", pos = {15, 15}, size = {40, 10}},
						{id = "grow_1", pos = {57, 15}, size = {0, 10}},
					},
				},
				{
					id = "row_2",
					pos = {10, 35},
					size = {52, 20},
					children = {
						{id = "text_2", pos = {15, 40}, size = {20, 10}},
						{id = "grow_2", pos = {37, 40}, size = {20, 10}},
					},
				},
			},
		},
	)
}

// TODO(Thomas): Add other tests where we overflow the max sizing within and outside
// of a fit sizing container.
// TODO(Thomas): The tests below that use a text_fit_wrapper container do so to
// make sure the element doesn't have to deal with the root's fixed size. I'm not
// sure if that's exactly what we want.

@(test)
test_basic_text_element_sizing :: proc(t: ^testing.T) {
	// A grow text sizes to its own text when min and max do not bind.
	check_layout(
		t,
		Element_Spec {
			id = "text_fit_wrapper",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {
				{
					id = "text",
					text = "012345",
					style = {
						sizing_x = Sizing{kind = .Grow, min_value = 50, max_value = 100},
						sizing_y = Sizing{kind = .Grow},
					},
				},
			},
		},
		Expected_Element {
			id = "text_fit_wrapper",
			pos = {0, 0},
			size = {60, 10},
			children = {{id = "text", pos = {0, 0}, size = {60, 10}}},
		},
	)
}


@(test)
test_text_element_sizing_with_newlines :: proc(t: ^testing.T) {
	// A newline splits text into rows and the width is the widest row.
	check_layout(
		t,
		Element_Spec {
			id = "text_fit_wrapper",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {{id = "text", text = "One\nTwo"}},
		},
		Expected_Element {
			id = "text_fit_wrapper",
			pos = {0, 0},
			size = {30, 20},
			children = {{id = "text", pos = {0, 0}, size = {30, 20}}},
		},
	)
}


@(test)
test_text_element_sizing_with_whitespace_overflowing_with_padding_and_text_wrapping :: proc(
	t: ^testing.T,
) {
	// Text wraps to fit the width its parent leaves after padding.
	check_layout(
		t,
		Element_Spec {
			id = "container",
			style = {
				sizing_x = sizing_fixed(60),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
			},
			children = {{id = "text", text = "Button 1", style = {text_wrap_mode = .Wrap}}},
		},
		Expected_Element {
			id = "container",
			pos = {0, 0},
			size = {60, 40},
			children = {{id = "text", pos = {10, 10}, size = {40, 20}}},
		},
	)
}

@(test)
test_basic_text_element_underflow_sizing :: proc(t: ^testing.T) {
	// A min clamps a grow text up when its own text is smaller.
	check_layout(
		t,
		Element_Spec {
			id = "text_fit_wrapper",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {
				{
					id = "text",
					text = "01",
					style = {
						sizing_x = Sizing{kind = .Grow, min_value = 50},
						sizing_y = Sizing{kind = .Grow, min_value = 20},
					},
				},
			},
		},
		Expected_Element {
			id = "text_fit_wrapper",
			pos = {0, 0},
			size = {50, 20},
			children = {{id = "text", pos = {0, 0}, size = {50, 20}}},
		},
	)
}


@(test)
test_iterated_texts_layout :: proc(t: ^testing.T) {
	// A Fit parent sums the widths of its text children.
	check_layout(
		t,
		Element_Spec {
			id = "parent",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {
				{id = "One", text = "One"},
				{id = "Two", text = "Two"},
				{id = "Three", text = "Three"},
				{id = "Four", text = "Four"},
				{id = "Five", text = "Five"},
			},
		},
		Expected_Element {
			id = "parent",
			pos = {0, 0},
			size = {190, 10},
			children = {
				{id = "One", pos = {0, 0}, size = {30, 10}},
				{id = "Two", pos = {30, 0}, size = {30, 10}},
				{id = "Three", pos = {60, 0}, size = {50, 10}},
				{id = "Four", pos = {110, 0}, size = {40, 10}},
				{id = "Five", pos = {150, 0}, size = {40, 10}},
			},
		},
	)
}

@(test)
test_text_overflows_parent_when_wrap_mode_none :: proc(t: ^testing.T) {
	// Wrap mode .None keeps the full text width and overflows the parent.
	check_layout(
		t,
		Element_Spec {
			id = "parent",
			style = {
				sizing_x = sizing_fixed(4 * MOCK_CHAR_WIDTH),
				sizing_y = sizing_fixed(MOCK_LINE_HEIGHT),
			},
			children = {{id = "text", text = "12345", style = {text_wrap_mode = .None}}},
		},
		Expected_Element {
			id = "parent",
			pos = {0, 0},
			size = {40, 10},
			children = {{id = "text", pos = {0, 0}, size = {50, 10}}},
		},
	)
}
