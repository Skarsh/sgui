package ui

import "core:testing"


@(test)
test_margin_spacing_between_siblings_ltr :: proc(t: ^testing.T) {
	// Sibling margins add along the main axis instead of collapsing (LTR).
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(500),
				sizing_y = sizing_fixed(200),
				layout_direction = .Left_To_Right,
				padding = padding_all(10),
			},
			children = {
				{
					name = "child_1",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(50),
						margin = Margin{left = 5, top = 5, right = 10, bottom = 5},
					},
				},
				{
					name = "child_2",
					style = {
						sizing_x = sizing_fixed(80),
						sizing_y = sizing_fixed(60),
						margin = Margin{left = 15, top = 8, right = 15, bottom = 8},
					},
				},
				{
					name = "child_3",
					style = {
						sizing_x = sizing_fixed(120),
						sizing_y = sizing_fixed(70),
						margin = Margin{left = 20, top = 10, right = 5, bottom = 10},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {500, 200},
			children = {
				{name = "child_1", pos = {15, 15}, size = {100, 50}},
				{name = "child_2", pos = {140, 18}, size = {80, 60}},
				{name = "child_3", pos = {255, 20}, size = {120, 70}},
			},
		},
	)
}


@(test)
test_margin_spacing_between_siblings_ttb :: proc(t: ^testing.T) {
	// Sibling margins add along the main axis instead of collapsing (TTB).
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(300),
				sizing_y = sizing_fixed(400),
				layout_direction = .Top_To_Bottom,
				padding = padding_all(15),
			},
			children = {
				{
					name = "child_1",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(80),
						margin = Margin{left = 5, top = 10, right = 5, bottom = 20},
					},
				},
				{
					name = "child_2",
					style = {
						sizing_x = sizing_fixed(120),
						sizing_y = sizing_fixed(60),
						margin = Margin{left = 8, top = 25, right = 8, bottom = 10},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {300, 400},
			children = {
				{name = "child_1", pos = {20, 25}, size = {100, 80}},
				{name = "child_2", pos = {23, 150}, size = {120, 60}},
			},
		},
	)
}


@(test)
test_margin_does_not_reduce_parent_content_size :: proc(t: ^testing.T) {
	// A parent's margin offsets it but does not shrink its content area.
	check_layout(
		t,
		Element_Spec {
			name = "grandparent",
			style = {sizing_x = sizing_fixed(600), sizing_y = sizing_fixed(500)},
			children = {
				{
					name = "parent",
					style = {
						sizing_x = sizing_fixed(300),
						sizing_y = sizing_fixed(200),
						padding = padding_all(20),
						margin = margin_all(50),
					},
					children = {
						{
							name = "child",
							style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(80)},
						},
					},
				},
			},
		},
		Expected_Element {
			name = "grandparent",
			pos = {0, 0},
			size = {600, 500},
			children = {
				{
					name = "parent",
					pos = {50, 50},
					size = {300, 200},
					children = {{name = "child", pos = {70, 70}, size = {100, 80}}},
				},
			},
		},
	)
}


@(test)
test_asymmetric_margins :: proc(t: ^testing.T) {
	// A child with no parent padding lands at its own left and top margin.
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(500),
				sizing_y = sizing_fixed(300),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "child_1",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(100),
						margin = Margin{left = 5, top = 10, right = 30, bottom = 15},
					},
				},
				{
					name = "child_2",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(100),
						margin = Margin{left = 40, top = 5, right = 10, bottom = 20},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {500, 300},
			children = {
				{name = "child_1", pos = {5, 10}, size = {100, 100}},
				{name = "child_2", pos = {175, 5}, size = {100, 100}},
			},
		},
	)
}

@(test)
test_fit_size_includes_child_margins :: proc(t: ^testing.T) {
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fit(),
				sizing_y = sizing_fit(),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "child",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(50),
						margin = Margin{left = 10, right = 20, top = 5, bottom = 15},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {130, 70},
			children = {{name = "child", pos = {10, 5}, size = {100, 50}}},
		},
	)
}

@(test)
test_grow_size_accounts_for_child_margins :: proc(t: ^testing.T) {
	check_layout(
		t,
		Element_Spec {
			name = "parent",
			style = {
				sizing_x = sizing_fixed(300),
				sizing_y = sizing_fixed(100),
				layout_direction = .Left_To_Right,
			},
			children = {
				{
					name = "fixed_child",
					style = {
						sizing_x = sizing_fixed(100),
						sizing_y = sizing_fixed(50),
						margin = Margin{left = 10, right = 20},
					},
				},
				{
					name = "grow_child",
					style = {
						sizing_x = sizing_grow(),
						sizing_y = sizing_fixed(50),
						margin = Margin{left = 5, right = 15},
					},
				},
			},
		},
		Expected_Element {
			name = "parent",
			pos = {0, 0},
			size = {300, 100},
			children = {
				{name = "fixed_child", pos = {10, 0}, size = {100, 50}},
				{name = "grow_child", pos = {135, 0}, size = {150, 50}},
			},
		},
	)
}
