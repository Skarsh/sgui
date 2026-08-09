package ui

import "core:testing"

import base "../base"


@(test)
test_fit_container_no_children :: proc(t: ^testing.T) {
	// An empty Fit container collapses to just its padding and border.
	check_layout(
		t,
		Element_Spec {
			name = "empty_panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				layout_direction = .Left_To_Right,
				padding = Padding{left = 10, top = 20, right = 15, bottom = 25},
				border = border_all(2),
				child_gap = 5,
			},
		},
		Expected_Element{name = "empty_panel", pos = {0, 0}, size = {29, 49}},
	)
}


@(test)
test_fit_container_nonzero_gap_only_anchored_children :: proc(t: ^testing.T) {
	// Anchored children don't add to Fit sizing and their gap is ignored.
	check_layout(
		t,
		Element_Spec {
			name = "anchored_panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
			},
			children = {
				{
					name = "anchor_child_1",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Left,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					name = "anchor_child_2",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Left,
						alignment_y = .Top,
						relative_position = base.Vec2{100, 0},
						position_mode = .Anchored,
					},
				},
			},
		},
		Expected_Element {
			name = "anchored_panel",
			pos = {0, 0},
			size = {20, 20},
			children = {
				{name = "anchor_child_1", pos = {10, 10}, size = {50, 50}},
				{name = "anchor_child_2", pos = {110, 10}, size = {50, 50}},
			},
		},
	)
}


@(test)
test_fit_sizing_ltr :: proc(t: ^testing.T) {
	// A Fit LTR panel sums child widths and takes the tallest child for height.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				layout_direction = .Left_To_Right,
				padding = padding_all(10),
				border = border_all(5),
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(150)},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {350, 180},
			children = {
				{name = "container_1", pos = {15, 15}, size = {100, 100}},
				{name = "container_2", pos = {125, 15}, size = {50, 150}},
				{name = "container_3", pos = {185, 15}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_fit_sizing_ttb :: proc(t: ^testing.T) {
	// A Fit TTB panel sums child heights and takes the widest child for width.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				layout_direction = .Top_To_Bottom,
				padding = padding_all(10),
				border = border_all(5),
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(150)},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {180, 450},
			children = {
				{name = "container_1", pos = {15, 15}, size = {100, 100}},
				{name = "container_2", pos = {15, 125}, size = {50, 150}},
				{name = "container_3", pos = {15, 285}, size = {150, 150}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_grow_sizing_ltr :: proc(t: ^testing.T) {
	// A grow child takes the leftover primary space in an LTR panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Left_To_Right,
				padding = padding_all(10),
				border = border_all(3),
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {13, 13}, size = {100, 100}},
				{name = "container_2", pos = {123, 13}, size = {304, 374}},
				{name = "container_3", pos = {437, 13}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_ltr :: proc(t: ^testing.T) {
	// Grow-x children clamp to their max and leave the extra space unused.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Left_To_Right,
				padding = Padding{left = 11, top = 12, right = 13, bottom = 14},
				border = border_all(4),
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_grow(max = 150), sizing_y = sizing_grow()},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(max = 50), sizing_y = sizing_grow()},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {15, 16}, size = {150, 366}},
				{name = "container_2", pos = {175, 16}, size = {50, 366}},
				{name = "container_3", pos = {235, 16}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_ttb :: proc(t: ^testing.T) {
	// A grow child takes the leftover primary space in a TTB panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
				padding = padding_all(10),
				border = Border{left = 1, top = 2, right = 3, bottom = 4},
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {11, 12}, size = {100, 100}},
				{name = "container_2", pos = {11, 122}, size = {576, 104}},
				{name = "container_3", pos = {11, 236}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_ttb :: proc(t: ^testing.T) {
	// Grow-y children clamp to their max and leave the extra space unused.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
				padding = padding_all(10),
				border = Border{left = 2, top = 3, right = 2, bottom = 3},
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 50)},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {12, 13}, size = {576, 100}},
				{name = "container_2", pos = {12, 123}, size = {576, 50}},
				{name = "container_3", pos = {12, 183}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_on_non_primary_axis_ltr :: proc(t: ^testing.T) {
	// A capped grow child's surplus goes to the only uncapped sibling (LTR).
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Left_To_Right,
				padding = padding_all(10),
				border = border_all(6),
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_grow(max = 100), sizing_y = sizing_grow(max = 100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 75)},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_grow(max = 150), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {16, 16}, size = {100, 100}},
				{name = "container_2", pos = {126, 16}, size = {298, 75}},
				{name = "container_3", pos = {434, 16}, size = {150, 368}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_on_non_primary_axis_ttb :: proc(t: ^testing.T) {
	// A capped grow child's surplus is spread over the uncapped siblings (TTB).
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(600),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
				padding = padding_all(10),
				border = Border{left = 7, top = 8, right = 9, bottom = 10},
				child_gap = 10,
			},
			children = {
				{
					name = "container_1",
					style = {sizing_x = sizing_grow(max = 100), sizing_y = sizing_grow(max = 100)},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_grow(max = 75), sizing_y = sizing_grow()},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 150)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{name = "container_1", pos = {17, 18}, size = {100, 100}},
				{name = "container_2", pos = {17, 128}, size = {75, 121}},
				{name = "container_3", pos = {17, 259}, size = {564, 121}},
			},
		},
	)
}


@(test)
test_grow_sizing_equal_factors_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// Two equal-factor grow children split the parent evenly.
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
			children = {
				{name = "child_1", style = {sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()}},
				{name = "child_2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{name = "child_1", pos = {0, 0}, size = {50, 100}},
				{name = "child_2", pos = {50, 0}, size = {50, 100}},
			},
		},
	)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// Grow text and box children reach equal widths in an LTR panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(300),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
				padding = padding_all(10),
				border = Border{left = 3, top = 4, right = 5, bottom = 6},
				child_gap = 10,
			},
			children = {
				{
					name = "text_1",
					text = "First",
					style = {sizing_x = sizing_grow(min = 10), sizing_y = sizing_grow()},
				},
				{
					name = "grow_box",
					style = {sizing_x = sizing_grow(min = 5), sizing_y = sizing_grow()},
				},
				{
					name = "text_2",
					text = "Last",
					style = {sizing_x = sizing_grow(min = 0), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {300, 100},
			children = {
				{name = "text_1", pos = {13, 14}, size = {84, 70}},
				{name = "grow_box", pos = {107, 14}, size = {84, 70}},
				{name = "text_2", pos = {201, 14}, size = {84, 70}},
			},
		},
	)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ttb :: proc(t: ^testing.T) {
	// Grow text and box children reach equal heights in a TTB panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				layout_direction = .Top_To_Bottom,
				padding = Padding{left = 10, top = 11, right = 12, bottom = 13},
				border = border_all(2),
				child_gap = 10,
			},
			children = {
				{
					name = "text_1",
					text = "First",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 10)},
				},
				{
					name = "grow_box",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 5)},
				},
				{
					name = "text_2",
					text = "Last",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 10)},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{name = "text_1", pos = {12, 13}, size = {74, 17.333}},
				{name = "grow_box", pos = {12, 40.333}, size = {74, 17.333}},
				{name = "text_2", pos = {12, 67.667}, size = {74, 17.333}},
			},
		},
	)
}


@(test)
test_basic_percentage_of_parent_sizing_ltr :: proc(t: ^testing.T) {
	// Percentage children take a fraction of the parent inner box side by side.
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
				border = border_all(2),
			},
			children = {
				{
					name = "child_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
				{
					name = "child_2",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{name = "child_1", pos = {2, 2}, size = {48, 48}},
				{name = "child_2", pos = {50, 2}, size = {48, 48}},
			},
		},
	)
}


@(test)
test_basic_percentage_of_parent_sizing_ttb :: proc(t: ^testing.T) {
	// Percentage children take a fraction of the parent inner box stacked.
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				layout_direction = .Top_To_Bottom,
				border = border_all(3),
			},
			children = {
				{
					name = "child_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
				{
					name = "child_2",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{name = "child_1", pos = {3, 3}, size = {47, 47}},
				{name = "child_2", pos = {3, 50}, size = {47, 47}},
			},
		},
	)
}


@(test)
test_pct_of_parent_sizing_with_min_and_pref_width_grow_elments_inside :: proc(t: ^testing.T) {
	// A grow child's min steals space from its equal-factor sibling.
	check_layout(
		t,
		Element_Spec {
			name = "main_container",
			style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100), border = border_all(1)},
			children = {
				{
					name = "grouping_container",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 1.0},
						sizing_y = Sizing{kind = .Percentage, value = 1.0},
					},
					children = {
						{
							name = "first_child",
							style = {sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()},
						},
						{
							name = "second_child",
							style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
						},
					},
				},
			},
		},
		Expected_Element {
			name = "main_container",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{
					name = "grouping_container",
					pos = {1, 1},
					size = {98, 98},
					children = {
						{name = "first_child", pos = {1, 1}, size = {50, 98}},
						{name = "second_child", pos = {51, 1}, size = {48, 98}},
					},
				},
			},
		},
	)
}


@(test)
test_pct_of_parent_sizing_with_fit_sizing_element_inside :: proc(t: ^testing.T) {
	// A Fit child inside a full-size percentage panel collapses to its padding.
	directions := [?]Layout_Direction{.Left_To_Right, .Top_To_Bottom}
	for direction in directions {
		check_layout(
			t,
			Element_Spec {
				name = "main_container",
				style = {
					sizing_x = sizing_fixed(100),
					sizing_y = sizing_fixed(100),
					border = border_all(2),
				},
				children = {
					{
						name = "panel_container",
						style = {
							sizing_x = Sizing{kind = .Percentage, value = 1.0},
							sizing_y = Sizing{kind = .Percentage, value = 1.0},
							layout_direction = direction,
						},
						children = {
							{
								name = "fit_element",
								style = {
									sizing_x = sizing_fit(),
									sizing_y = sizing_fit(),
									padding = padding_all(20),
								},
							},
						},
					},
				},
			},
			Expected_Element {
				name = "main_container",
				pos = {0, 0},
				size = {100, 100},
				children = {
					{
						name = "panel_container",
						pos = {2, 2},
						size = {96, 96},
						children = {{name = "fit_element", pos = {2, 2}, size = {40, 40}}},
					},
				},
			},
		)
	}
}


@(test)
test_pct_of_parent_sizing_with_fixed_container_and_grow_container_siblings :: proc(t: ^testing.T) {
	// A percentage child and a fixed child leave the rest for a grow sibling.
	check_layout(
		t,
		Element_Spec {
			name = "main_container",
			style = {sizing_x = sizing_grow(), sizing_y = sizing_fixed(20), border = border_all(1)},
			children = {
				{
					name = "container_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.1},
						sizing_y = sizing_grow(),
					},
				},
				{
					name = "container_2",
					style = {sizing_x = sizing_fixed(20), sizing_y = sizing_grow()},
				},
				{
					name = "container_3",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			name = "main_container",
			pos = {0, 0},
			size = {500, 20},
			children = {
				{name = "container_1", pos = {1, 1}, size = {49.8, 18}},
				{name = "container_2", pos = {50.8, 1}, size = {20, 18}},
				{name = "container_3", pos = {70.8, 1}, size = {428.2, 18}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_fit_sizing_respects_max_size_constraint :: proc(t: ^testing.T) {
	// A Fit container clamps to its max instead of growing to a large child.
	check_layout(
		t,
		Element_Spec {
			name = "fit_container",
			style = {
				sizing_x = sizing_fit(0, 100),
				sizing_y = sizing_fit(0, 100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "large_child",
					style = {sizing_x = sizing_fixed(300), sizing_y = sizing_fixed(300)},
				},
			},
		},
		Expected_Element {
			name = "fit_container",
			pos = {0, 0},
			size = {100, 100},
			children = {{name = "large_child", pos = {0, 0}, size = {300, 300}}},
		},
	)
}


@(test)
test_fit_sizing_respects_min_size_constraint :: proc(t: ^testing.T) {
	// A Fit container clamps up to its min instead of shrinking to a small child.
	check_layout(
		t,
		Element_Spec {
			name = "fit_container",
			style = {
				sizing_x = sizing_fit(200),
				sizing_y = sizing_fit(200),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "small_child", style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(50)}},
			},
		},
		Expected_Element {
			name = "fit_container",
			pos = {0, 0},
			size = {200, 200},
			children = {{name = "small_child", pos = {0, 0}, size = {50, 50}}},
		},
	)
}


@(test)
test_text_element_size_includes_border :: proc(t: ^testing.T) {
	// A text element's Fit size includes its text plus padding plus border.
	check_layout(
		t,
		Element_Spec {
			name = "wrapper",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {
				{
					name = "bordered_text",
					text = "Button",
					style = {
						sizing_x = sizing_fit(),
						sizing_y = sizing_fit(),
						padding = Padding{left = 12, top = 8, right = 12, bottom = 8},
						border = border_all(2),
					},
				},
			},
		},
		Expected_Element {
			name = "wrapper",
			pos = {0, 0},
			size = {88, 30},
			children = {{name = "bordered_text", pos = {0, 0}, size = {88, 30}}},
		},
	)
}


@(test)
test_grow_equal_factors :: proc(t: ^testing.T) {
	// Three equal-factor grow children split the panel width evenly.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(300),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{name = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{name = "c3", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {300, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {100, 100}},
				{name = "c2", pos = {100, 0}, size = {100, 100}},
				{name = "c3", pos = {200, 0}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_grow_weighted_factors :: proc(t: ^testing.T) {
	// Weighted grow factors split the panel width in proportion.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "c1",
					style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				},
				{
					name = "c2",
					style = {sizing_x = sizing_grow_weighted(2), sizing_y = sizing_grow()},
				},
				{
					name = "c3",
					style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {100, 100}},
				{name = "c2", pos = {100, 0}, size = {200, 100}},
				{name = "c3", pos = {300, 0}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_shrink_proportional_to_factor :: proc(t: ^testing.T) {
	// Fixed children keep their size even when the panel is too small.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(240),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_fixed(100, 0), sizing_y = sizing_grow()}},
				{name = "c2", style = {sizing_x = sizing_fixed(200, 0), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {240, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {100, 100}},
				{name = "c2", pos = {100, 0}, size = {200, 100}},
			},
		},
	)
}


@(test)
test_shrink_grow_elements :: proc(t: ^testing.T) {
	// Two equal-factor grow children split the space when the panel is too small.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(240),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{name = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {240, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {120, 100}},
				{name = "c2", pos = {120, 0}, size = {120, 100}},
			},
		},
	)
}


@(test)
test_zero_grow_factor_excluded :: proc(t: ^testing.T) {
	// A factor 0 child gets no grow space and the rest split what is left.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
				{name = "c2", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
				{name = "c3", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {200, 100}},
				{name = "c2", pos = {200, 0}, size = {0, 100}},
				{name = "c3", pos = {200, 0}, size = {200, 100}},
			},
		},
	)
}


@(test)
test_weighted_grow_with_max_constraint :: proc(t: ^testing.T) {
	// A weighted grow child that hits its max gives the rest to its sibling.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "c1",
					style = {sizing_x = sizing_grow_weighted(1, 0, 100), sizing_y = sizing_grow()},
				},
				{name = "c2", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {100, 100}},
				{name = "c2", pos = {100, 0}, size = {300, 100}},
			},
		},
	)
}


@(test)
test_all_zero_factors :: proc(t: ^testing.T) {
	// With all grow factors 0 no space is distributed and children stay at 0.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
				{name = "c2", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{name = "c1", pos = {0, 0}, size = {0, 100}},
				{name = "c2", pos = {0, 0}, size = {0, 100}},
			},
		},
	)
}


@(test)
test_weighted_grow_ttb :: proc(t: ^testing.T) {
	// Weighted grow factors split the panel height in proportion.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
			},
			children = {
				{name = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)}},
				{name = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(2)}},
				{name = "c3", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)}},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {100, 400},
			children = {
				{name = "c1", pos = {0, 0}, size = {100, 100}},
				{name = "c2", pos = {0, 100}, size = {100, 200}},
				{name = "c3", pos = {0, 300}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_anchored_fit_ltr :: proc(t: ^testing.T) {
	// An anchored child does not add to a Fit panel's size in an LTR panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "normal",
					style = {sizing_x = sizing_fixed(200), sizing_y = sizing_fixed(300)},
				},
				{
					name = "anchored",
					style = {
						sizing_x = sizing_fixed(300),
						sizing_y = sizing_fixed(200),
						margin = margin_trbl(7, 8, 9, 10),
						position_mode = .Anchored,
					},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {220, 320},
			children = {
				{name = "normal", pos = {10, 10}, size = {200, 300}},
				{name = "anchored", pos = {20, 17}, size = {300, 200}},
			},
		},
	)
}


@(test)
test_anchored_fit_ttb :: proc(t: ^testing.T) {
	// An anchored child does not add to a Fit panel's size in a TTB panel.
	check_layout(
		t,
		Element_Spec {
			name = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
				layout_direction = .Top_To_Bottom,
			},
			children = {
				{
					name = "normal",
					style = {sizing_x = sizing_fixed(300), sizing_y = sizing_fixed(200)},
				},
				{
					name = "anchored",
					style = {
						sizing_x = sizing_fixed(200),
						sizing_y = sizing_fixed(300),
						margin = margin_trbl(7, 8, 9, 10),
						position_mode = .Anchored,
					},
				},
			},
		},
		Expected_Element {
			name = "panel",
			pos = {0, 0},
			size = {320, 220},
			children = {
				{name = "normal", pos = {10, 10}, size = {300, 200}},
				{name = "anchored", pos = {20, 17}, size = {200, 300}},
			},
		},
	)
}

