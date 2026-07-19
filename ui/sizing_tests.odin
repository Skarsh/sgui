package ui

import "core:testing"

import base "../base"


@(test)
test_fit_container_no_children :: proc(t: ^testing.T) {
	// An empty Fit container collapses to just its padding plus border.
	//
	// width  = 10+15 pad + 2+2 border = 29
	// height = 20+25 pad + 2+2 border = 49
	check_layout(
		t,
		Element_Spec {
			id = "empty_panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				layout_direction = .Left_To_Right,
				padding = Padding{left = 10, top = 20, right = 15, bottom = 25},
				border = border_all(2),
				child_gap = 5,
			},
		},
		Expected_Element{id = "empty_panel", pos = {0, 0}, size = {29, 49}},
	)
}


@(test)
test_fit_container_nonzero_gap_only_anchored_children :: proc(t: ^testing.T) {
	// Anchored children don't contribute to fit sizing, and with no flow
	// children the child_gap is ignored, so the panel collapses to just its
	// padding while the children overflow it.
	check_layout(
		t,
		Element_Spec {
			id = "anchored_panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
			},
			children = {
				{
					id = "anchor_child_1",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Left,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					id = "anchor_child_2",
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
			id = "anchored_panel",
			pos = {0, 0},
			size = {20, 20},
			children = {
				{id = "anchor_child_1", pos = {10, 10}, size = {50, 50}},
				{id = "anchor_child_2", pos = {110, 10}, size = {50, 50}},
			},
		},
	)
}


@(test)
test_fit_sizing_ltr :: proc(t: ^testing.T) {
	// A Fit LTR panel sums its children's widths (plus gaps, padding, border)
	// and takes the tallest child for its height.
	//
	// width  = 100+50+150 + 2*10 gap + 10+10 pad + 5+5 border = 350
	// height = 150 (tallest child) + 10+10 pad + 5+5 border   = 180
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(150)},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {350, 180},
			children = {
				{id = "container_1", pos = {15, 15}, size = {100, 100}},
				{id = "container_2", pos = {125, 15}, size = {50, 150}},
				{id = "container_3", pos = {185, 15}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_fit_sizing_ttb :: proc(t: ^testing.T) {
	// A Fit TTB panel sums its children's heights (plus gaps, padding, border)
	// and takes the widest child for its width.
	//
	// height = 100+150+150 + 2*10 gap + 10+10 pad + 5+5 border = 450
	// width  = 150 (widest child) + 10+10 pad + 5+5 border     = 180
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(150)},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {180, 450},
			children = {
				{id = "container_1", pos = {15, 15}, size = {100, 100}},
				{id = "container_2", pos = {15, 125}, size = {50, 150}},
				{id = "container_3", pos = {15, 285}, size = {150, 150}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_grow_sizing_ltr :: proc(t: ^testing.T) {
	// A single grow child between two fixed siblings takes the leftover primary
	// (x) space and fills the cross (y) axis.
	//
	// c2 width  = inner 574 - fixed (100+150) - 2*10 gap = 304
	// c2 height = inner height 374
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {13, 13}, size = {100, 100}},
				{id = "container_2", pos = {123, 13}, size = {304, 374}},
				{id = "container_3", pos = {437, 13}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_ltr :: proc(t: ^testing.T) {
	// LTR grow-x children clamp to their maxes next to a fixed sibling. Both
	// grow children are capped, so the leftover primary space is just unused
	// with no surplus to redistribute.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_grow(max = 150), sizing_y = sizing_grow()},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(max = 50), sizing_y = sizing_grow()},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {15, 16}, size = {150, 366}},
				{id = "container_2", pos = {175, 16}, size = {50, 366}},
				{id = "container_3", pos = {235, 16}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_ttb :: proc(t: ^testing.T) {
	// A single grow child between two fixed siblings takes the leftover primary
	// (y) space and fills the cross (x) axis.
	//
	// c2 height = inner 374 - fixed (100+150) - 2*10 gap = 104
	// c2 width  = inner width 576
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {11, 12}, size = {100, 100}},
				{id = "container_2", pos = {11, 122}, size = {576, 104}},
				{id = "container_3", pos = {11, 236}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_ttb :: proc(t: ^testing.T) {
	// TTB grow-y children clamp to their maxes next to a fixed sibling. Both
	// grow children are capped, so the leftover primary space is just unused
	// with no surplus to redistribute.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 50)},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_fixed(150), sizing_y = sizing_fixed(150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {12, 13}, size = {576, 100}},
				{id = "container_2", pos = {12, 123}, size = {576, 50}},
				{id = "container_3", pos = {12, 183}, size = {150, 150}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_on_non_primary_axis_ltr :: proc(t: ^testing.T) {
	// LTR grow where two children clamp on the primary axis (x) and c2, the only
	// uncapped one, absorbs all of their surplus. Cross axis (y) just clamps
	// each child to its own max.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_grow(max = 100), sizing_y = sizing_grow(max = 100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 75)},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_grow(max = 150), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {16, 16}, size = {100, 100}},
				{id = "container_2", pos = {126, 16}, size = {298, 75}},
				{id = "container_3", pos = {434, 16}, size = {150, 368}},
			},
		},
	)
}


@(test)
test_grow_sizing_max_value_on_non_primary_axis_ttb :: proc(t: ^testing.T) {
	// TTB grow where a clamped child's surplus is spread over the uncapped ones.
	//
	// Primary axis (y): share = 114 each. c1 clamps to its max 100, freeing 14.
	// That 14 splits over the 2 uncapped children (c2, and c3 whose max 150
	// doesn't bind), so c2 and c3 become 114 + 7 = 121.
	//
	// Cross axis (x): each child just clamps to its own max independently.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "container_1",
					style = {sizing_x = sizing_grow(max = 100), sizing_y = sizing_grow(max = 100)},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_grow(max = 75), sizing_y = sizing_grow()},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(max = 150)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {600, 400},
			children = {
				{id = "container_1", pos = {17, 18}, size = {100, 100}},
				{id = "container_2", pos = {17, 128}, size = {75, 121}},
				{id = "container_3", pos = {17, 259}, size = {564, 121}},
			},
		},
	)
}


@(test)
test_grow_sizing_equal_factors_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// Two equal-factor grow children split a fixed 100x100 parent evenly. Each
	// targets 100/2 = 50, child_1's min=50 exactly meets that, so it doesn't
	// bind.
	check_layout(
		t,
		Element_Spec {
			id = "parent",
			style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
			children = {
				{id = "child_1", style = {sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()}},
				{id = "child_2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "child_1", pos = {0, 0}, size = {50, 100}},
				{id = "child_2", pos = {50, 0}, size = {50, 100}},
			},
		},
	)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// Two text elements and a plain box, all grow, reach equal widths in an LTR
	// panel even with different (non-binding) min widths of 10 / 5 / 0. The
	// panel has an asymmetric border {l=3, t=4, r=5, b=6}.
	//
	// avail_w = 300 - 10 - 10 - 3 - 5 - 2*10 gap = 252, split 3 ways = 84 each
	// height  = 100 - 10 - 10 - 4 - 6            = 70
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "text_1",
					text = "First",
					style = {sizing_x = sizing_grow(min = 10), sizing_y = sizing_grow()},
				},
				{
					id = "grow_box",
					style = {sizing_x = sizing_grow(min = 5), sizing_y = sizing_grow()},
				},
				{
					id = "text_2",
					text = "Last",
					style = {sizing_x = sizing_grow(min = 0), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {300, 100},
			children = {
				{id = "text_1", pos = {13, 14}, size = {84, 70}},
				{id = "grow_box", pos = {107, 14}, size = {84, 70}},
				{id = "text_2", pos = {201, 14}, size = {84, 70}},
			},
		},
	)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ttb :: proc(t: ^testing.T) {
	// Two text elements and a plain box, all grow, reach equal heights in a TTB
	// panel even with different (non-binding) min heights of 10 / 5 / 10.
	//
	// avail_h = 100 - 11 - 13 - 2 - 2 - 2*10 gap = 52, split 3 ways = 17.333 each
	// width   = 100 - 10 - 12 - 2 - 2            = 74
	check_layout(
		t,
		Element_Spec {
			id = "panel",
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
					id = "text_1",
					text = "First",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 10)},
				},
				{
					id = "grow_box",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 5)},
				},
				{
					id = "text_2",
					text = "Last",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow(min = 10)},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "text_1", pos = {12, 13}, size = {74, 17.333}},
				{id = "grow_box", pos = {12, 40.333}, size = {74, 17.333}},
				{id = "text_2", pos = {12, 67.667}, size = {74, 17.333}},
			},
		},
	)
}


@(test)
test_basic_percentage_of_parent_sizing_ltr :: proc(t: ^testing.T) {
	// Two 50% x 50% children sit side by side inside a fixed 100x100 parent
	// with a 2px border (no padding, no gap).
	//
	// inner = {100-4, 100-4} = {96, 96}, so each child is 50% = {48, 48}
	check_layout(
		t,
		Element_Spec {
			id = "parent",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
				border = border_all(2),
			},
			children = {
				{
					id = "child_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
				{
					id = "child_2",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
			},
		},
		Expected_Element {
			id = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "child_1", pos = {2, 2}, size = {48, 48}},
				{id = "child_2", pos = {50, 2}, size = {48, 48}},
			},
		},
	)
}


@(test)
test_basic_percentage_of_parent_sizing_ttb :: proc(t: ^testing.T) {
	// Two 50% x 50% children stack vertically inside a fixed 100x100 parent
	// with a 3px border (no padding, no gap).
	//
	// inner = {100-6, 100-6} = {94, 94}, so each child is 50% = {47, 47}
	check_layout(
		t,
		Element_Spec {
			id = "parent",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				layout_direction = .Top_To_Bottom,
				border = border_all(3),
			},
			children = {
				{
					id = "child_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
				{
					id = "child_2",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.5},
						sizing_y = Sizing{kind = .Percentage, value = 0.5},
					},
				},
			},
		},
		Expected_Element {
			id = "parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "child_1", pos = {3, 3}, size = {47, 47}},
				{id = "child_2", pos = {3, 50}, size = {47, 47}},
			},
		},
	)
}


@(test)
test_pct_of_parent_sizing_with_min_and_pref_width_grow_elments_inside :: proc(t: ^testing.T) {
	// A min-width grow element steals space from its equal-factor sibling. Two
	// grow children share the 98px inner width (100 minus the 1px border on
	// each side): equal factors target 49 each, but first_child's min=50 clamps
	// it up to 50, leaving 48 for second_child.
	check_layout(
		t,
		Element_Spec {
			id = "main_container",
			style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100), border = border_all(1)},
			children = {
				{
					id = "grouping_container",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 1.0},
						sizing_y = Sizing{kind = .Percentage, value = 1.0},
					},
					children = {
						{
							id = "first_child",
							style = {sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()},
						},
						{
							id = "second_child",
							style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
						},
					},
				},
			},
		},
		Expected_Element {
			id = "main_container",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{
					id = "grouping_container",
					pos = {1, 1},
					size = {98, 98},
					children = {
						{id = "first_child", pos = {1, 1}, size = {50, 98}},
						{id = "second_child", pos = {51, 1}, size = {48, 98}},
					},
				},
			},
		},
	)
}


@(test)
test_pct_of_parent_sizing_with_fit_sizing_element_inside :: proc(t: ^testing.T) {
	// A 100% x 100% panel inside a fixed 100x100 container (2px border, no
	// padding) fills the {96, 96} inner box. The Fit child collapses to just
	// its own padding, {40, 40}. Layout direction doesn't matter here, so the
	// panel has a single child, meaning LTR and TTB place it identically.
	directions := [?]Layout_Direction{.Left_To_Right, .Top_To_Bottom}
	for direction in directions {
		check_layout(
			t,
			Element_Spec {
				id = "main_container",
				style = {
					sizing_x = sizing_fixed(100),
					sizing_y = sizing_fixed(100),
					border = border_all(2),
				},
				children = {
					{
						id = "panel_container",
						style = {
							sizing_x = Sizing{kind = .Percentage, value = 1.0},
							sizing_y = Sizing{kind = .Percentage, value = 1.0},
							layout_direction = direction,
						},
						children = {
							{
								id = "fit_element",
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
				id = "main_container",
				pos = {0, 0},
				size = {100, 100},
				children = {
					{
						id = "panel_container",
						pos = {2, 2},
						size = {96, 96},
						children = {{id = "fit_element", pos = {2, 2}, size = {40, 40}}},
					},
				},
			},
		)
	}
}


@(test)
test_pct_of_parent_sizing_with_fixed_container_and_grow_container_siblings :: proc(t: ^testing.T) {
	// Percentage, Fixed, and Grow siblings share the inner width of a
	// grow-width / fixed-height container with a 1px border (padding 0).
	//
	// main   = grow x fills 500 window, fixed 20 tall => {500, 20}
	// inner  = {500-2, 20-2} = {498, 18}, content origin {1, 1}
	// c1     = 10% of 498 = 49.8 wide           => pos {1, 1},    size {49.8, 18}
	// c2     = fixed 20 wide                     => pos {50.8, 1}, size {20, 18}
	// c3     = grow gets the rest 498-49.8-20    => pos {70.8, 1}, size {428.2, 18}
	check_layout(
		t,
		Element_Spec {
			id = "main_container",
			style = {sizing_x = sizing_grow(), sizing_y = sizing_fixed(20), border = border_all(1)},
			children = {
				{
					id = "container_1",
					style = {
						sizing_x = Sizing{kind = .Percentage, value = 0.1},
						sizing_y = sizing_grow(),
					},
				},
				{
					id = "container_2",
					style = {sizing_x = sizing_fixed(20), sizing_y = sizing_grow()},
				},
				{
					id = "container_3",
					style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			id = "main_container",
			pos = {0, 0},
			size = {500, 20},
			children = {
				{id = "container_1", pos = {1, 1}, size = {49.8, 18}},
				{id = "container_2", pos = {50.8, 1}, size = {20, 18}},
				{id = "container_3", pos = {70.8, 1}, size = {428.2, 18}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_fit_sizing_respects_max_size_constraint :: proc(t: ^testing.T) {
	// A Fit container with max=100 holding a 300x300 child is clamped down to
	// 100x100, NOT expanded to the child size. The fixed child doesn't shrink,
	// so it keeps its 300x300 and overflows the container.
	check_layout(
		t,
		Element_Spec {
			id = "fit_container",
			style = {
				sizing_x = sizing_fit(0, 100),
				sizing_y = sizing_fit(0, 100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					id = "large_child",
					style = {sizing_x = sizing_fixed(300), sizing_y = sizing_fixed(300)},
				},
			},
		},
		Expected_Element {
			id = "fit_container",
			pos = {0, 0},
			size = {100, 100},
			children = {{id = "large_child", pos = {0, 0}, size = {300, 300}}},
		},
	)
}


@(test)
test_fit_sizing_respects_min_size_constraint :: proc(t: ^testing.T) {
	// A Fit container with min=200 holding a 50x50 child is clamped up to
	// 200x200, NOT shrink-wrapped to the child size. The child keeps its
	// fixed 50x50.
	check_layout(
		t,
		Element_Spec {
			id = "fit_container",
			style = {
				sizing_x = sizing_fit(200),
				sizing_y = sizing_fit(200),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "small_child", style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(50)}},
			},
		},
		Expected_Element {
			id = "fit_container",
			pos = {0, 0},
			size = {200, 200},
			children = {{id = "small_child", pos = {0, 0}, size = {50, 50}}},
		},
	)
}


@(test)
test_text_element_size_includes_border :: proc(t: ^testing.T) {
	// A text element's fit size includes text + padding + border, and a Fit
	// wrapper shrink-wraps to that same size.
	//
	// text "Button" = 6 chars * 10 = {60, 10}
	// width  = 60 + 12 + 12 + 2 + 2 = 88
	// height = 10 +  8 +  8 + 2 + 2 = 30
	check_layout(
		t,
		Element_Spec {
			id = "wrapper",
			style = {sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			children = {
				{
					id = "bordered_text",
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
			id = "wrapper",
			pos = {0, 0},
			size = {88, 30},
			children = {{id = "bordered_text", pos = {0, 0}, size = {88, 30}}},
		},
	)
}


@(test)
test_grow_equal_factors :: proc(t: ^testing.T) {
	// Three equal-factor grow children split the panel width evenly.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(300),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{id = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{id = "c3", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {300, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {100, 100}},
				{id = "c2", pos = {100, 0}, size = {100, 100}},
				{id = "c3", pos = {200, 0}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_grow_weighted_factors :: proc(t: ^testing.T) {
	// Weighted grow factors [1,2,1] over 400px split as [100, 200, 100].
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					id = "c1",
					style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				},
				{
					id = "c2",
					style = {sizing_x = sizing_grow_weighted(2), sizing_y = sizing_grow()},
				},
				{
					id = "c3",
					style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {100, 100}},
				{id = "c2", pos = {100, 0}, size = {200, 100}},
				{id = "c3", pos = {300, 0}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_shrink_proportional_to_factor :: proc(t: ^testing.T) {
	// Fixed sizing doesn't participate in shrink, so children keep their
	// sizes even though the panel doesn't have enough space (100+200 > 240).
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(240),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_fixed(100, 0), sizing_y = sizing_grow()}},
				{id = "c2", style = {sizing_x = sizing_fixed(200, 0), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {240, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {100, 100}},
				{id = "c2", pos = {100, 0}, size = {200, 100}},
			},
		},
	)
}


@(test)
test_shrink_grow_elements :: proc(t: ^testing.T) {
	// Shrink behavior with Grow elements: two grow elements with equal
	// grow_factor split the space equally.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(240),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
				{id = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {240, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {120, 100}},
				{id = "c2", pos = {120, 0}, size = {120, 100}},
			},
		},
	)
}


@(test)
test_zero_grow_factor_excluded :: proc(t: ^testing.T) {
	// A factor=0 child doesn't participate in grow distribution: c2 stays at
	// 0, c1 and c3 split the 400px equally.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
				{id = "c2", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
				{id = "c3", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {200, 100}},
				{id = "c2", pos = {200, 0}, size = {0, 100}},
				{id = "c3", pos = {200, 0}, size = {200, 100}},
			},
		},
	)
}


@(test)
test_weighted_grow_with_max_constraint :: proc(t: ^testing.T) {
	// Weighted grow where one child hits its max constraint.
	// factors [1,1], 400px, but c1 has max=100: c1 gets 100 (hits max),
	// remaining 300px goes to c2.
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					id = "c1",
					style = {sizing_x = sizing_grow_weighted(1, 0, 100), sizing_y = sizing_grow()},
				},
				{id = "c2", style = {sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {100, 100}},
				{id = "c2", pos = {100, 0}, size = {300, 100}},
			},
		},
	)
}


@(test)
test_all_zero_factors :: proc(t: ^testing.T) {
	// All factors are 0, so no grow distribution happens, children stay at
	// their initial size (0).
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(400),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
				{id = "c2", style = {sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {400, 100},
			children = {
				{id = "c1", pos = {0, 0}, size = {0, 100}},
				{id = "c2", pos = {0, 0}, size = {0, 100}},
			},
		},
	)
}


@(test)
test_weighted_grow_ttb :: proc(t: ^testing.T) {
	// Weighted distribution on the Y axis (Top_To_Bottom layout).
	// factors [1,2,1] on Y axis, 400px => [100, 200, 100]
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
			},
			children = {
				{id = "c1", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)}},
				{id = "c2", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(2)}},
				{id = "c3", style = {sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)}},
			},
		},
		Expected_Element {
			id = "panel",
			pos = {0, 0},
			size = {100, 400},
			children = {
				{id = "c1", pos = {0, 0}, size = {100, 100}},
				{id = "c2", pos = {0, 100}, size = {100, 200}},
				{id = "c3", pos = {0, 300}, size = {100, 100}},
			},
		},
	)
}


@(test)
test_anchored_fit_ltr :: proc(t: ^testing.T) {
	// Panel is Fit + Left_To_Right. Only "normal" is a flow child. "anchored"
	// is position_mode = .Anchored, so it does not contribute to fit sizing and
	// the child_gap collapses to 0 (a single flow child has no gaps).
	//
	// panel  = normal + padding = {200+10+10, 300+10+10} = {220, 320}
	// normal = at padding origin  = {10, 10}
	// anchored = padding + margin.{left,top} = {10+10, 10+7} = {20, 17}
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					id = "normal",
					style = {sizing_x = sizing_fixed(200), sizing_y = sizing_fixed(300)},
				},
				{
					id = "anchored",
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
			id = "panel",
			pos = {0, 0},
			size = {220, 320},
			children = {
				{id = "normal", pos = {10, 10}, size = {200, 300}},
				{id = "anchored", pos = {20, 17}, size = {300, 200}},
			},
		},
	)
}


@(test)
test_anchored_fit_ttb :: proc(t: ^testing.T) {
	// Panel is Fit + Top_To_Bottom. Only "normal" is a flow child. "anchored"
	// is position_mode = .Anchored, so it does not contribute to fit sizing and
	// the child_gap collapses to 0 (a single flow child has no gaps).
	//
	// panel  = normal + padding = {300+10+10, 200+10+10} = {320, 220}
	// normal = at padding origin  = {10, 10}
	// anchored = padding + margin.{left,top} = {10+10, 10+7} = {20, 17}
	check_layout(
		t,
		Element_Spec {
			id = "panel",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				padding = padding_all(10),
				child_gap = 10,
				layout_direction = .Top_To_Bottom,
			},
			children = {
				{
					id = "normal",
					style = {sizing_x = sizing_fixed(300), sizing_y = sizing_fixed(200)},
				},
				{
					id = "anchored",
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
			id = "panel",
			pos = {0, 0},
			size = {320, 220},
			children = {
				{id = "normal", pos = {10, 10}, size = {300, 200}},
				{id = "anchored", pos = {20, 17}, size = {200, 300}},
			},
		},
	)
}

