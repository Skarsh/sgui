package ui

import "core:testing"

import base "../base"


@(test)
test_basic_container_alignments_ltr :: proc(t: ^testing.T) {
	// alignment_x and alignment_y place a child inside its parent.
	Alignment_Case :: struct {
		alignment_x:  Alignment_X,
		alignment_y:  Alignment_Y,
		expected_pos: base.Vec2,
	}

	cases := []Alignment_Case {
		{.Left, .Top, {0, 0}},
		{.Center, .Top, {25, 0}},
		{.Right, .Top, {50, 0}},
		{.Left, .Center, {0, 25}},
		{.Center, .Center, {25, 25}},
		{.Right, .Center, {50, 25}},
		{.Left, .Bottom, {0, 50}},
		{.Center, .Bottom, {25, 50}},
		{.Right, .Bottom, {50, 50}},
	}

	for c in cases {
		check_layout(
			t,
			Element_Spec {
				id = "parent",
				style = {
					sizing_x = sizing_fixed(100),
					sizing_y = sizing_fixed(100),
					alignment_x = c.alignment_x,
					alignment_y = c.alignment_y,
				},
				children = {
					{
						id = "container",
						style = {sizing_x = sizing_fixed(50), sizing_y = sizing_fixed(50)},
					},
				},
			},
			Expected_Element {
				id = "parent",
				pos = {0, 0},
				size = {100, 100},
				children = {{id = "container", pos = c.expected_pos, size = {50, 50}}},
			},
		)
	}
}


@(test)
test_relative_layout_anchoring :: proc(t: ^testing.T) {
	// An anchored child pins to a corner of its parent and takes no flow space.

	check_layout(
		t,
		Element_Spec {
			id = "relative_parent",
			style = {sizing_x = sizing_fixed(200), sizing_y = sizing_fixed(200)},
			children = {
				{
					id = "child_tl",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Left,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_tr",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Right,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_br",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Right,
						alignment_y = .Bottom,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_bl",
					style = {
						sizing_x = sizing_fixed(50),
						sizing_y = sizing_fixed(50),
						alignment_x = .Left,
						alignment_y = .Bottom,
						position_mode = .Anchored,
					},
				},
			},
		},
		Expected_Element {
			id = "relative_parent",
			pos = {0, 0},
			size = {200, 200},
			children = {
				{id = "child_tl", pos = {0, 0}, size = {50, 50}},
				{id = "child_tr", pos = {150, 0}, size = {50, 50}},
				{id = "child_br", pos = {150, 150}, size = {50, 50}},
				{id = "child_bl", pos = {0, 150}, size = {50, 50}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_relative_layout_with_offsets :: proc(t: ^testing.T) {
	// relative_position offsets an anchored child from its corner.

	check_layout(
		t,
		Element_Spec {
			id = "relative_parent",
			style = {sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(100)},
			children = {
				{
					id = "child_offset_tl",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Left,
						alignment_y = .Top,
						position_mode = .Anchored,
						relative_position = base.Vec2{10, 15},
					},
				},
				{
					id = "child_offset_tr",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Right,
						alignment_y = .Top,
						position_mode = .Anchored,
						relative_position = base.Vec2{-5, 10},
					},
				},
				{
					id = "child_offset_br",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Right,
						alignment_y = .Bottom,
						position_mode = .Anchored,
						relative_position = base.Vec2{-5, -5},
					},
				},
				{
					id = "child_offset_bl",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Left,
						alignment_y = .Bottom,
						position_mode = .Anchored,
						relative_position = base.Vec2{10, -5},
					},
				},
			},
		},
		Expected_Element {
			id = "relative_parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "child_offset_tl", pos = {10, 15}, size = {20, 20}},
				{id = "child_offset_tr", pos = {75, 10}, size = {20, 20}},
				{id = "child_offset_br", pos = {75, 75}, size = {20, 20}},
				{id = "child_offset_bl", pos = {10, 75}, size = {20, 20}},
			},
		},
		window_size = {500, 500},
	)
}


@(test)
test_relative_layout_padding_and_border_influence :: proc(t: ^testing.T) {
	// An anchored child anchors to the content box so padding and border push it inward.

	check_layout(
		t,
		Element_Spec {
			id = "relative_parent",
			style = {
				sizing_x = sizing_fixed(100),
				sizing_y = sizing_fixed(100),
				padding = Padding{left = 10, right = 20, top = 5, bottom = 15},
				border = Border{left = 5, right = 7, top = 8, bottom = 10},
			},
			children = {
				{
					id = "child_tl",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Left,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_tr",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Right,
						alignment_y = .Top,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_br",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Right,
						alignment_y = .Bottom,
						position_mode = .Anchored,
					},
				},
				{
					id = "child_bl",
					style = {
						sizing_x = sizing_fixed(20),
						sizing_y = sizing_fixed(20),
						alignment_x = .Left,
						alignment_y = .Bottom,
						position_mode = .Anchored,
					},
				},
			},
		},
		Expected_Element {
			id = "relative_parent",
			pos = {0, 0},
			size = {100, 100},
			children = {
				{id = "child_tl", pos = {15, 13}, size = {20, 20}},
				{id = "child_tr", pos = {53, 13}, size = {20, 20}},
				{id = "child_br", pos = {53, 55}, size = {20, 20}},
				{id = "child_bl", pos = {15, 55}, size = {20, 20}},
			},
		},
		window_size = {500, 500},
	)
}
