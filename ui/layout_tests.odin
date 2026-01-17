package ui

import "core:testing"

import base "../base"


@(test)
test_fit_container_no_children :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding: Padding,
	}

	test_data := Test_Data {
		panel_padding = Padding{left = 10, top = 20, right = 15, bottom = 25},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := Sizing {
			kind = .Fit,
		}
		layout_direction := Layout_Direction.Left_To_Right
		padding := &data.panel_padding
		child_gap: f32 = 5
		container(
			ctx,
			"empty_panel",
			Config_Options {
				layout = {
					sizing = {&sizing, &sizing},
					layout_direction = &layout_direction,
					padding = padding,
					child_gap = &child_gap,
				},
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := base.Vec2 {
			f32(DEFAULT_TESTING_WINDOW_SIZE.x),
			f32(DEFAULT_TESTING_WINDOW_SIZE.y),
		}
		size := base.Vec2 {
			data.panel_padding.left + data.panel_padding.right,
			data.panel_padding.top + data.panel_padding.bottom,
		}
		pos := base.Vec2{0, 0}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element{{id = "empty_panel", pos = pos, size = size}},
		}
		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_fit_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:              base.Vec2,
		panel_layout_direction: Layout_Direction,
		panel_sizing:           [2]Sizing,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		container_1_size:       base.Vec2,
		container_2_size:       base.Vec2,
		container_3_size:       base.Vec2,
		largest_container_y:    f32,
	}
	test_data := Test_Data {
		root_size = {500, 500},
		panel_layout_direction = .Left_To_Right,
		panel_sizing = {Sizing{kind = .Fit}, Sizing{kind = .Fit}},
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		container_1_size = base.Vec2{100, 100},
		container_2_size = base.Vec2{50, 150},
		container_3_size = base.Vec2{150, 150},
		largest_container_y = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&data.panel_sizing.x, &data.panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container_1_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_1_size.x},
					{kind = .Fixed, value = data.container_1_size.y},
				}

				container_2_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_2_size.x},
					{kind = .Fixed, value = data.container_2_size.y},
				}

				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)

				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)

				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		panel_pos := base.Vec2{0, 0}
		panel_size := base.Vec2 {
			data.panel_padding.left +
			data.panel_padding.right +
			data.panel_child_gap * 2 +
			data.container_1_size.x +
			data.container_2_size.x +
			data.container_3_size.x,
			data.largest_container_y + data.panel_padding.top + data.panel_padding.bottom,
		}

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + data.container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + data.container_2_size.x + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element {
				{
					id = "panel",
					pos = panel_pos,
					size = panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}
		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)

}


@(test)
test_fit_sizing_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:              base.Vec2,
		panel_layout_direction: Layout_Direction,
		panel_sizing:           [2]Sizing,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		container_1_size:       base.Vec2,
		container_2_size:       base.Vec2,
		container_3_size:       base.Vec2,
		largest_container_x:    f32,
	}
	test_data := Test_Data {
		root_size = {500, 500},
		panel_layout_direction = .Top_To_Bottom,
		panel_sizing = {Sizing{kind = .Fit}, Sizing{kind = .Fit}},
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		container_1_size = {100, 100},
		container_2_size = {50, 150},
		container_3_size = {150, 150},
		largest_container_x = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&data.panel_sizing.x, &data.panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container_1_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_1_size.x},
					{kind = .Fixed, value = data.container_1_size.y},
				}
				container_2_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_2_size.x},
					{kind = .Fixed, value = data.container_2_size.y},
				}
				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)

				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)

				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		panel_size := base.Vec2 {
			data.largest_container_x + data.panel_padding.left + data.panel_padding.right,
			data.panel_padding.top +
			data.panel_padding.bottom +
			data.panel_child_gap * 2 +
			data.container_1_size.y +
			data.container_2_size.y +
			data.container_3_size.y,
		}

		panel_pos := base.Vec2{0, 0}
		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + data.container_1_size.y + data.panel_child_gap
		c3_pos_y := c2_pos_y + data.container_2_size.y + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element {
				{
					id = "panel",
					pos = panel_pos,
					size = panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left, c2_pos_y},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left, c3_pos_y},
							size = data.container_3_size,
						},
					},
				},
			},
		}
		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)

}

@(test)
test_grow_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Grow_Sizing_Ltr_Context :: struct {
		panel_layout_direction: Layout_Direction,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		container_1_size:       base.Vec2,
		container_3_size:       base.Vec2,
	}

	test_context := Test_Grow_Sizing_Ltr_Context {
		panel_layout_direction = .Left_To_Right,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
				container_1_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_1_size.x},
					{kind = .Fixed, value = data.container_1_size.y},
				}
				container_2_sizing := [2]Sizing{{kind = .Grow}, {kind = .Grow}}
				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}
				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)

				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)

				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(
		t: ^testing.T,
		ctx: ^Context,
		root: ^UI_Element,
		data: ^Test_Grow_Sizing_Ltr_Context,
	) {
		inner_panel_w := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		inner_panel_h := data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		total_fixed_w := data.container_1_size.x + data.container_3_size.x
		total_gap_w := data.panel_child_gap * 2
		container_2_w := inner_panel_w - total_fixed_w - total_gap_w

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + data.container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + container_2_w + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = {container_2_w, inner_panel_h},
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])

	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_context)
}


@(test)
test_grow_sizing_max_value_ltr :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_layout_direction:       Layout_Direction,
		panel_padding:                Padding,
		panel_child_gap:              f32,
		panel_size:                   base.Vec2,
		container_1_max_value:        f32,
		container_2_max_value:        f32,
		container_3_size:             base.Vec2,
		container_3_layout_direction: Layout_Direction,
	}

	test_data := Test_Data {
		panel_layout_direction = .Left_To_Right,
		panel_padding = Padding{left = 11, top = 12, right = 13, bottom = 14},
		panel_child_gap = 10,
		panel_size = base.Vec2{600, 400},
		container_1_max_value = 150,
		container_2_max_value = 50,
		container_3_size = base.Vec2{150, 150},
		container_3_layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container_1_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_1_max_value},
					{kind = .Grow},
				}
				container_2_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_2_max_value},
					{kind = .Grow},
				}
				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)
				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)
				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		container_1_size := base.Vec2 {
			data.container_1_max_value,
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom,
		}

		container_2_size := base.Vec2 {
			data.container_2_max_value,
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom,
		}

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + container_2_size.x + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_grow_sizing_ttb :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction: Layout_Direction,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		container_1_size:       base.Vec2,
		container_3_size:       base.Vec2,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container_1_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_1_size.x},
					{kind = .Fixed, value = data.container_1_size.y},
				}
				container_2_sizing := [2]Sizing{{kind = .Grow}, {kind = .Grow}}
				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)
				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)
				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		inner_panel_w := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		inner_panel_h := data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		total_fixed_h := data.container_1_size.y + data.container_3_size.y
		total_gap_h := data.panel_child_gap * 2
		container_2_h := inner_panel_h - total_fixed_h - total_gap_h

		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + data.container_1_size.y + data.panel_child_gap
		c3_pos_y := c2_pos_y + container_2_h + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left, c2_pos_y},
							size = {inner_panel_w, container_2_h},
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left, c3_pos_y},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_sizing_max_value_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction:       Layout_Direction,
		panel_padding:                Padding,
		panel_child_gap:              f32,
		panel_size:                   base.Vec2,
		container_1_max_value:        f32,
		container_2_max_value:        f32,
		container_3_size:             base.Vec2,
		container_3_layout_direction: Layout_Direction,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value = 100,
		container_2_max_value = 50,
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container_1_sizing := [2]Sizing {
					{kind = .Grow},
					{kind = .Grow, max_value = data.container_1_max_value},
				}
				container_2_sizing := [2]Sizing {
					{kind = .Grow},
					{kind = .Grow, max_value = data.container_2_max_value},
				}
				container_3_sizing := [2]Sizing {
					{kind = .Fixed, value = data.container_3_size.x},
					{kind = .Fixed, value = data.container_3_size.y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)
				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)
				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		container_1_size := base.Vec2 {
			data.panel_size.x - data.panel_padding.left - data.panel_padding.right,
			data.container_1_max_value,
		}

		container_2_size := base.Vec2 {
			data.panel_size.x - data.panel_padding.left - data.panel_padding.right,
			data.container_2_max_value,
		}

		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + container_1_size.y + data.panel_child_gap
		c3_pos_y := c2_pos_y + container_2_size.y + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left, c2_pos_y},
							size = container_2_size,
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left, c3_pos_y},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_sizing_max_value_on_non_primary_axis_ltr :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction:  Layout_Direction,
		panel_padding:           Padding,
		panel_child_gap:         f32,
		panel_size:              base.Vec2,
		container_1_max_value_x: f32,
		container_1_max_value_y: f32,
		container_2_max_value_y: f32,
		container_3_max_value_x: f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Left_To_Right,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value_x = 100,
		container_1_max_value_y = 100,
		container_2_max_value_y = 75,
		container_3_max_value_x = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container_1_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_1_max_value_x},
					{kind = .Grow, max_value = data.container_1_max_value_y},
				}

				container_2_sizing := [2]Sizing {
					{kind = .Grow},
					{kind = .Grow, max_value = data.container_2_max_value_y},
				}

				container_3_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_3_max_value_x},
					{kind = .Grow},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)

				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)

				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		// --- Primary Axis Calculation (X-axis) ---
		num_children := 3
		panel_inner_width := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		total_gap_width := f32(num_children - 1) * data.panel_child_gap
		available_primary_space := panel_inner_width - total_gap_width
		initial_share_x := available_primary_space / f32(num_children)

		// Pass 1: Calculate total surplus from all clamped elements.
		surplus_x: f32 = 0
		uncapped_count := 0

		// Check container 1
		if initial_share_x > data.container_1_max_value_x {
			surplus_x += initial_share_x - data.container_1_max_value_x
		} else {
			uncapped_count += 1
		}

		// Check container 2 (no max_x, always uncapped)
		uncapped_count += 1

		// Check container 3
		if initial_share_x > data.container_3_max_value_x {
			surplus_x += initial_share_x - data.container_3_max_value_x
		} else {
			uncapped_count += 1
		}

		// Pass 2: Distribute surplus and calculate final sizes.
		surplus_share_x: f32 = 0
		if uncapped_count > 0 {
			surplus_share_x = surplus_x / f32(uncapped_count)
		}

		// Calculate final width of each container based on whether it was clamped
		c1_final_x := min(initial_share_x, data.container_1_max_value_x)
		if c1_final_x == initial_share_x {
			c1_final_x += surplus_share_x
		}

		// c2 has no max value, so it was not clamped and always gets the surplus share
		c2_final_x := initial_share_x + surplus_share_x

		c3_final_x := min(initial_share_x, data.container_3_max_value_x)
		if c3_final_x == initial_share_x {
			c3_final_x += surplus_share_x
		}

		// --- Cross Axis Calculation (Y-axis) ---
		panel_inner_height :=
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom
		c1_final_y := min(panel_inner_height, data.container_1_max_value_y)
		c2_final_y := min(panel_inner_height, data.container_2_max_value_y)
		c3_final_y := panel_inner_height

		// --- Final Sizes and Positions
		c1_size := base.Vec2{c1_final_x, c1_final_y}
		c2_size := base.Vec2{c2_final_x, c2_final_y}
		c3_size := base.Vec2{c3_final_x, c3_final_y}

		c1_pos := base.Vec2{data.panel_padding.left, data.panel_padding.top}
		c2_pos := base.Vec2{c1_pos.x + c1_size.x + data.panel_child_gap, data.panel_padding.top}
		c3_pos := base.Vec2{c2_pos.x + c2_size.x + data.panel_child_gap, data.panel_padding.top}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{id = "container_1", pos = c1_pos, size = c1_size},
						{id = "container_2", pos = c2_pos, size = c2_size},
						{id = "container_3", pos = c3_pos, size = c3_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_grow_sizing_max_value_on_non_primary_axis_ttb :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction:  Layout_Direction,
		panel_padding:           Padding,
		panel_child_gap:         f32,
		panel_size:              base.Vec2,
		container_1_max_value_x: f32,
		container_1_max_value_y: f32,
		container_2_max_value_x: f32,
		container_3_max_value_y: f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value_x = 100,
		container_1_max_value_y = 100,
		container_2_max_value_x = 75,
		container_3_max_value_y = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container_1_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_1_max_value_x},
					{kind = .Grow, max_value = data.container_1_max_value_y},
				}

				container_2_sizing := [2]Sizing {
					{kind = .Grow, max_value = data.container_2_max_value_x},
					{kind = .Grow},
				}

				container_3_sizing := [2]Sizing {
					{kind = .Grow},
					{kind = .Grow, max_value = data.container_3_max_value_y},
				}

				container(
					ctx,
					"container_1",
					Config_Options {
						layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}},
					},
				)

				container(
					ctx,
					"container_2",
					Config_Options {
						layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}},
					},
				)

				container(
					ctx,
					"container_3",
					Config_Options {
						layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		// --- Primary Axis Calculation (Y-axis) ---
		num_children := 3
		panel_inner_height :=
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom
		total_gap_height := f32(num_children - 1) * data.panel_child_gap
		available_primary_space := panel_inner_height - total_gap_height
		initial_share_y := available_primary_space / f32(num_children)

		// Pass 1: Calculate total surplus from all clamped elements.
		surplus_y: f32 = 0
		uncapped_count := 0

		// Check container 1
		if initial_share_y > data.container_1_max_value_y {
			surplus_y += initial_share_y - data.container_1_max_value_y
		} else {
			uncapped_count += 1
		}

		// Check container 2 (no max_y, always uncapped)
		uncapped_count += 1

		// Check container 3
		if initial_share_y > data.container_3_max_value_y {
			surplus_y += initial_share_y - data.container_3_max_value_y
		} else {
			uncapped_count += 1
		}

		// Pass 2: Distribute surplus and calculate final sizes.
		surplus_share_y: f32 = 0
		if uncapped_count > 0 {
			surplus_share_y = surplus_y / f32(uncapped_count)
		}

		// Calculate final width of each container based on whether it was clamped
		c1_final_y := min(initial_share_y, data.container_1_max_value_y)
		if c1_final_y == initial_share_y {
			c1_final_y += surplus_share_y
		}

		// c2 has no max value, so it was not clamped and always gets the surplus share
		c2_final_y := initial_share_y + surplus_share_y

		c3_final_y := min(initial_share_y, data.container_3_max_value_y)
		if c3_final_y == initial_share_y {
			c3_final_y += surplus_share_y
		}

		// --- Cross Axis Calculation (X-axis) ---
		panel_inner_width := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		c1_final_x := min(panel_inner_width, data.container_1_max_value_x)
		c2_final_x := min(panel_inner_width, data.container_2_max_value_x)
		c3_final_x := panel_inner_width

		// --- Final Sizes and Positions
		c1_size := base.Vec2{c1_final_x, c1_final_y}
		c2_size := base.Vec2{c2_final_x, c2_final_y}
		c3_size := base.Vec2{c3_final_x, c3_final_y}

		c1_pos := base.Vec2{data.panel_padding.left, data.panel_padding.top}
		c2_pos := base.Vec2{data.panel_padding.left, c1_pos.y + c1_size.y + data.panel_child_gap}
		c3_pos := base.Vec2{data.panel_padding.left, c2_pos.y + c2_size.y + data.panel_child_gap}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{id = "container_1", pos = c1_pos, size = c1_size},
						{id = "container_2", pos = c2_pos, size = c2_size},
						{id = "container_3", pos = c3_pos, size = c3_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_sizing_min_width_and_pref_width_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		layout_direction: Layout_Direction,
	}

	test_data := Test_Data {
		parent_width     = 100,
		parent_height    = 100,
		layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_width},
			{kind = .Fixed, value = data.parent_height},
		}
		container(
			ctx,
			"parent",
			Config_Options{layout = {sizing = {&parent_sizing.x, &parent_sizing.y}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				child_1_sizing := [2]Sizing{{kind = .Grow, min_value = 50}, {kind = .Grow}}
				container(
					ctx,
					"child_1",
					Config_Options{layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}}},
				)

				child_2_sizing := [2]Sizing{{kind = .Grow, value = 70}, {kind = .Grow}}

				container(
					ctx,
					"child_2",
					Config_Options{layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}}},
				)
			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}
		parent_size := base.Vec2{data.parent_width, data.parent_height}

		// Same pos since no padding etc
		child_1_pos := parent_pos
		child_1_size := base.Vec2{50, 100}

		child_2_pos := base.Vec2{child_1_pos.x + child_1_size.x, parent_pos.y}
		child_2_size := base.Vec2{50, 100}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "parent",
					pos = parent_pos,
					size = parent_size,
					children = []Expected_Element {
						{id = "child_1", pos = child_1_pos, size = child_1_size, children = {}},
						{id = "child_2", pos = child_2_pos, size = child_2_size, children = {}},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)

}

@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction: Layout_Direction,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		text_1_min_width:       f32,
		grow_box_min_width:     f32,
		text_2_min_width:       f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Left_To_Right,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {300, 100},
		text_1_min_width = 10,
		grow_box_min_width = 5,
		text_2_min_width = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				text(
					ctx,
					"text_1",
					"First",
					Config_Options {
						layout = {
							sizing = {
								&{kind = .Grow, min_value = data.text_1_min_width},
								&{kind = .Grow},
							},
						},
					},
				)

				grow_box_sizing := [2]Sizing {
					{kind = .Grow, min_value = data.grow_box_min_width},
					{kind = .Grow},
				}

				container(
					ctx,
					"grow_box",
					Config_Options{layout = {sizing = {&grow_box_sizing.x, &grow_box_sizing.y}}},
				)

				text(
					ctx,
					"text_2",
					"Last",
					Config_Options {
						layout = {
							sizing = {
								&{kind = .Grow, min_value = data.text_2_min_width},
								&{kind = .Grow},
							},
						},
					},
				)

			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		available_width :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			2 * data.panel_child_gap

		expected_child_width := available_width / 3
		expected_child_height :=
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + expected_child_width + data.panel_child_gap
		c3_pos_x := c2_pos_x + expected_child_width + data.panel_child_gap


		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "text_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "grow_box",
							pos = {c2_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "text_2",
							pos = {c3_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_layout_direction: Layout_Direction,
		panel_padding:          Padding,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		text_1_min_height:      f32,
		grow_box_min_height:    f32,
		text_2_min_height:      f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 11, right = 12, bottom = 13},
		panel_child_gap = 10,
		panel_size = {100, 100},
		text_1_min_height = 10,
		grow_box_min_height = 5,
		text_2_min_height = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		panel_sizing := [2]Sizing {
			{kind = .Fixed, value = data.panel_size.x},
			{kind = .Fixed, value = data.panel_size.y},
		}
		container(
			ctx,
			"panel",
			Config_Options {
				layout = {
					sizing = {&panel_sizing.x, &panel_sizing.y},
					layout_direction = &data.panel_layout_direction,
					padding = &data.panel_padding,
					child_gap = &data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text_1",
					"First",
					Config_Options {
						layout = {
							sizing = {
								&{kind = .Grow},
								&{kind = .Grow, min_value = data.text_1_min_height},
							},
						},
					},
				)

				grow_box_sizing := [2]Sizing {
					{kind = .Grow},
					{kind = .Grow, min_value = data.grow_box_min_height},
				}

				container(
					ctx,
					"grow_box",
					Config_Options{layout = {sizing = {&grow_box_sizing.x, &grow_box_sizing.y}}},
				)

				text(
					ctx,
					"text_2",
					"Last",
					Config_Options {
						layout = {
							sizing = {
								&{kind = .Grow},
								&{kind = .Grow, min_value = data.text_1_min_height},
							},
						},
					},
				)

			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		available_height :=
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			2 * data.panel_child_gap

		expected_child_width :=
			data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		expected_child_height := available_height / 3

		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + expected_child_height + data.panel_child_gap
		c3_pos_y := c2_pos_y + expected_child_height + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "text_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "grow_box",
							pos = {data.panel_padding.left, c2_pos_y},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "text_2",
							pos = {data.panel_padding.left, c3_pos_y},
							size = {expected_child_width, expected_child_height},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_fit_element_with_multiple_rows_of_text_and_pure_grow_sizing_elements :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		main_layout_direction: Layout_Direction,
		main_padding:          Padding,
		main_child_gap:        f32,
		row_layout_direction:  Layout_Direction,
		row_padding:           Padding,
		row_child_gap:         f32,
	}

	test_data := Test_Data {
		main_layout_direction = .Top_To_Bottom,
		main_padding          = {10, 10, 10, 10},
		main_child_gap        = 5,
		row_layout_direction  = .Left_To_Right,
		row_padding           = {5, 5, 5, 5},
		row_child_gap         = 2,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		main_sizing := [2]Sizing{{kind = .Fit}, {kind = .Fit}}
		if begin_container(
			ctx,
			"main",
			Config_Options {
				layout = {
					sizing = {&main_sizing.x, &main_sizing.y},
					padding = &data.main_padding,
					child_gap = &data.main_child_gap,
					layout_direction = &data.main_layout_direction,
				},
			},
		) {

			// Row 1
			if begin_container(
				ctx,
				"row_1",
				Config_Options {
					layout = {padding = &data.row_padding, child_gap = &data.row_child_gap},
				},
			) {
				text(ctx, "text_1", "AAAA")
				spacer(ctx, "spacer_1")
				end_container(ctx)
			}


			// Row 2
			if begin_container(
				ctx,
				"row_2",
				Config_Options {
					layout = {padding = &data.row_padding, child_gap = &data.row_child_gap},
				},
			) {
				text(ctx, "text_2", "AA")
				spacer(ctx, "spacer_2")
				end_container(ctx)
			}

			end_container(ctx)
		}
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		text_1_size := base.Vec2{4 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT}
		text_2_size := base.Vec2{2 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT}

		row_1_size := base.Vec2 {
			data.row_padding.left +
			text_1_size.x +
			data.row_child_gap +
			0 +
			data.row_padding.right,
			data.row_padding.top + text_1_size.y + data.row_padding.bottom,
		}

		main_content_width := row_1_size.x
		row_2_stretched_size := base.Vec2{main_content_width, row_1_size.y}
		row_2_content_width :=
			row_2_stretched_size.x - data.row_padding.left - data.row_padding.right
		spacer_2_width := row_2_content_width - text_2_size.x - data.row_child_gap
		spacer_2_size := base.Vec2{spacer_2_width, MOCK_LINE_HEIGHT}

		// spacer_1 has no space to grow into
		spacer_1_size := base.Vec2{0, MOCK_LINE_HEIGHT}

		main_size := base.Vec2 {
			data.main_padding.left + data.main_padding.right + row_1_size.x,
			data.main_padding.top +
			data.main_padding.bottom +
			row_1_size.y +
			row_2_stretched_size.y +
			data.main_child_gap,
		}

		main_pos := base.Vec2{0, 0}
		row_1_pos := base.Vec2 {
			main_pos.x + data.main_padding.left,
			main_pos.y + data.main_padding.top,
		}
		row_2_pos := base.Vec2{row_1_pos.x, row_1_pos.y + row_1_size.y + data.main_child_gap}

		text_1_pos := base.Vec2 {
			row_1_pos.x + data.row_padding.left,
			row_1_pos.y + data.row_padding.top,
		}
		spacer_1_pos := base.Vec2{text_1_pos.x + text_1_size.x + data.row_child_gap, text_1_pos.y}

		text_2_pos := base.Vec2 {
			row_2_pos.x + data.row_padding.left,
			row_2_pos.y + data.row_padding.top,
		}
		spacer_2_pos := base.Vec2{text_2_pos.x + text_2_size.x + data.row_child_gap, text_2_pos.y}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "main",
					pos = main_pos,
					size = main_size,
					children = []Expected_Element {
						{
							id = "row_1",
							pos = row_1_pos,
							size = row_1_size,
							children = {
								{id = "text_1", pos = text_1_pos, size = text_1_size},
								{id = "spacer_1", pos = spacer_1_pos, size = spacer_1_size},
							},
						},
						{
							id = "row_2",
							pos = row_2_pos,
							size = row_2_stretched_size,
							children = {
								{id = "text_2", pos = text_2_pos, size = text_2_size},
								{id = "spacer_2", pos = spacer_2_pos, size = spacer_2_size},
							},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

// TODO(Thomas): Add other tests where we overflow the max sizing within and outside
// of a fit sizing container.
// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_basic_text_element_sizing :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		text_min_width: f32,
		text_max_width: f32,
	}

	test_data := Test_Data {
		text_min_width = 50,
		text_max_width = 100,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := [2]Sizing{{kind = .Fit}, {kind = .Fit}}
		container(
			ctx,
			"text_fit_wrapper",
			Config_Options{layout = {sizing = {&sizing.x, &sizing.y}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text",
					"012345",
					Config_Options {
						layout = {
							sizing = {
								&{
									kind = .Grow,
									min_value = data.text_min_width,
									max_value = data.text_max_width,
								},
								&{kind = .Grow},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = 6 * MOCK_CHAR_WIDTH
		text_height: f32 = MOCK_LINE_HEIGHT

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = "text", pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_text_element_sizing_with_newlines :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		id:   string,
		text: string,
	}

	test_data := Test_Data {
		id   = "text",
		text = "One\nTwo",
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := [2]Sizing{{kind = .Fit}, {kind = .Fit}}
		container(
			ctx,
			"text_fit_wrapper",
			Config_Options{layout = {sizing = {&sizing.x, &sizing.y}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(ctx, data.id, data.text)
			},
		)

	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = 3 * MOCK_CHAR_WIDTH
		text_height: f32 = 2 * MOCK_LINE_HEIGHT

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = data.id, pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_text_element_sizing_with_whitespace_overflowing_with_padding :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		container_id:      string,
		container_padding: Padding,
		text_id:           string,
		text:              string,
	}

	test_data := Test_Data {
		container_id = "container",
		container_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		text_id = "text",
		text = "Button 1",
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := [2]Sizing{{kind = .Fixed, value = 60}, {kind = .Fit}}
		container(
			ctx,
			data.container_id,
			Config_Options {
				layout = {sizing = {&sizing.x, &sizing.y}, padding = &data.container_padding},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(ctx, data.text_id, data.text)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		padding := data.container_padding
		container_size := base.Vec2{60, 2 * MOCK_LINE_HEIGHT + padding.top + padding.bottom}

		// Space for text is size of the text minus paddings
		text_size := base.Vec2 {
			6 * MOCK_CHAR_WIDTH - padding.left - padding.right,
			2 * MOCK_LINE_HEIGHT,
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					data.container_id,
					{0, 0},
					container_size,
					{{data.text_id, {padding.left, padding.top}, text_size, {}}},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_basic_text_element_underflow_sizing :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		text_min_width:  f32,
		text_min_height: f32,
	}

	test_data := Test_Data {
		text_min_width  = 50,
		text_min_height = 20,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		sizing := [2]Sizing{{kind = .Fit}, {kind = .Fit}}
		container(
			ctx,
			"text_fit_wrapper",
			Config_Options{layout = {sizing = {&sizing.x, &sizing.y}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text",
					"01",
					Config_Options {
						layout = {
							sizing = {
								&{kind = .Grow, min_value = data.text_min_width},
								&{kind = .Grow, min_value = data.text_min_height},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = data.text_min_width
		text_height: f32 = data.text_min_height

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = "text", pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_iterated_texts_layout :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		items: [5]string,
	}

	test_data := Test_Data {
		items = {"One", "Two", "Three", "Four", "Five"},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := [2]Sizing{{kind = .Fit}, {kind = .Fit}}
		container(
			ctx,
			"parent",
			Config_Options{layout = {sizing = {&sizing.x, &sizing.y}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				for item in data.items {
					text(ctx, item, item)
				}
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		expected_elements: [5]Expected_Element
		width_offset: f32 = 0
		for item, idx in data.items {
			width := f32(len(item) * MOCK_CHAR_WIDTH)
			expected_elements[idx] = Expected_Element {
				id   = item,
				pos  = {width_offset, 0},
				size = {width, MOCK_LINE_HEIGHT},
			}

			width_offset += width
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = expected_elements[:],
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_basic_container_alignments_ltr :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		parent_pos:       base.Vec2,
		alignment_x:      Alignment_X,
		alignment_y:      Alignment_Y,
		container_width:  f32,
		container_height: f32,
		container_pos:    base.Vec2,
	}

	generate_test_data :: proc(
		parent_height: f32,
		parent_width: f32,
		container_width: f32,
		container_height: f32,
		alignment_x: Alignment_X,
		alignment_y: Alignment_Y,
	) -> Test_Data {

		container_pos: base.Vec2
		switch alignment_x {
		case .Left:
			container_pos.x = 0
		case .Center:
			container_pos.x = (parent_width / 2) - (container_width / 2)
		case .Right:
			container_pos.x = parent_width - container_width
		}

		switch alignment_y {
		case .Top:
			container_pos.y = 0
		case .Center:
			container_pos.y = (parent_height / 2) - (container_height / 2)
		case .Bottom:
			container_pos.y = parent_height - container_height
		}

		return Test_Data {
			parent_width = parent_width,
			parent_height = parent_height,
			parent_pos = {0, 0},
			alignment_x = alignment_x,
			alignment_y = alignment_y,
			container_width = container_width,
			container_height = container_height,
			container_pos = container_pos,
		}
	}

	parent_width: f32 = 100
	parent_height: f32 = 100
	container_width: f32 = 50
	container_height: f32 = 50

	tests_data := []Test_Data {
		// Left-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Top,
		),
		// Center-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Top,
		),
		// Right-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Top,
		),
		// Left-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Center,
		),
		// Center-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Center,
		),
		// Right-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Center,
		),
		// Left-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Bottom,
		),
		// Center-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Bottom,
		),
		// Right-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Bottom,
		),
	}


	for &test_data in tests_data {
		// --- 2. Define the UI Building Logic ---
		build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
			parent_sizing := [2]Sizing {
				{kind = .Fixed, value = data.parent_width},
				{kind = .Fixed, value = data.parent_height},
			}
			container(
				ctx,
				"parent",
				Config_Options {
					layout = {
						sizing = {&parent_sizing.x, &parent_sizing.y},
						alignment_x = &data.alignment_x,
						alignment_y = &data.alignment_y,
					},
				},
				data,
				proc(ctx: ^Context, data: ^Test_Data) {
					container_sizing := [2]Sizing {
						{kind = .Fixed, value = data.container_width},
						{kind = .Fixed, value = data.container_height},
					}
					container(
						ctx,
						"container",
						Config_Options {
							layout = {sizing = {&container_sizing.x, &container_sizing.y}},
						},
					)
				},
			)
		}

		// --- 3. Define the Verification Logic ---
		verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
			expected_layout_tree := Expected_Element {
				id       = "root",
				children = []Expected_Element {
					{
						id = "parent",
						pos = data.parent_pos,
						size = {data.parent_width, data.parent_height},
						children = []Expected_Element {
							{
								id = "container",
								pos = data.container_pos,
								size = {data.container_width, data.container_height},
							},
						},
					},
				},
			}

			expect_layout(t, ctx, root, expected_layout_tree.children[0])
		}

		// --- 4. Run the Test ---
		run_ui_test(t, build_ui_proc, verify_proc, &test_data)
	}
}

@(test)
test_basic_percentage_of_parent_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		parent_pos:       base.Vec2,
		child_gap:        f32,
		child_1_pct_x:    f32,
		child_1_pct_y:    f32,
		child_2_pct_x:    f32,
		child_2_pct_y:    f32,
		child_3_pct_x:    f32,
		child_3_pct_y:    f32,
		layout_direction: Layout_Direction,
	}

	test_data := Test_Data {
		parent_width     = 100,
		parent_height    = 100,
		parent_pos       = {0, 0},
		child_1_pct_x    = 0.5,
		child_1_pct_y    = 0.5,
		child_2_pct_x    = 0.5,
		child_2_pct_y    = 0.5,
		child_3_pct_x    = 0,
		child_3_pct_y    = 0,
		layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_width},
			{kind = .Fixed, value = data.parent_height},
		}

		container(
			ctx,
			"parent",
			Config_Options {
				layout = {
					sizing = {&parent_sizing.x, &parent_sizing.y},
					layout_direction = &data.layout_direction,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				// Child 1
				child_1_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = data.child_1_pct_x},
					{kind = .Percentage_Of_Parent, value = data.child_1_pct_y},
				}
				container(
					ctx,
					"child_1",
					Config_Options{layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}}},
				)

				// Child 2
				child_2_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = data.child_2_pct_x},
					{kind = .Percentage_Of_Parent, value = data.child_2_pct_y},
				}
				container(
					ctx,
					"child_2",
					Config_Options{layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}}},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// No padding so its the same as the parent pos
		child_1_pos := base.Vec2{data.parent_pos.x, data.parent_pos.y}
		child_1_size := base.Vec2 {
			data.parent_width * data.child_1_pct_x,
			data.parent_height * data.child_1_pct_y,
		}

		child_2_pos := base.Vec2{child_1_pos.x + child_1_size.x, child_1_pos.y}

		child_2_size := base.Vec2 {
			data.parent_width * data.child_2_pct_x,
			data.parent_height * data.child_2_pct_y,
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "parent",
					pos = data.parent_pos,
					size = {data.parent_width, data.parent_height},
					children = []Expected_Element {
						{
							id = "child_1",
							pos = child_1_pos,
							size = child_1_size,
							children = []Expected_Element{},
						},
						{
							id = "child_2",
							pos = child_2_pos,
							size = child_2_size,
							children = []Expected_Element{},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_basic_percentage_of_parent_sizing_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		parent_pos:       base.Vec2,
		child_gap:        f32,
		child_1_pct_x:    f32,
		child_1_pct_y:    f32,
		child_2_pct_x:    f32,
		child_2_pct_y:    f32,
		child_3_pct_x:    f32,
		child_3_pct_y:    f32,
		layout_direction: Layout_Direction,
	}

	test_data := Test_Data {
		parent_width     = 100,
		parent_height    = 100,
		parent_pos       = {0, 0},
		child_1_pct_x    = 0.5,
		child_1_pct_y    = 0.5,
		child_2_pct_x    = 0.5,
		child_2_pct_y    = 0.5,
		child_3_pct_x    = 0,
		child_3_pct_y    = 0,
		layout_direction = .Top_To_Bottom,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_width},
			{kind = .Fixed, value = data.parent_height},
		}

		container(
			ctx,
			"parent",
			Config_Options {
				layout = {
					sizing = {&parent_sizing.x, &parent_sizing.y},
					layout_direction = &data.layout_direction,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				// Child 1
				child_1_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = data.child_1_pct_x},
					{kind = .Percentage_Of_Parent, value = data.child_1_pct_y},
				}
				container(
					ctx,
					"child_1",
					Config_Options{layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}}},
				)

				// Child 2
				child_2_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = data.child_2_pct_x},
					{kind = .Percentage_Of_Parent, value = data.child_2_pct_y},
				}
				container(
					ctx,
					"child_2",
					Config_Options{layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}}},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// No padding so its the same as the parent pos
		child_1_pos := base.Vec2{data.parent_pos.x, data.parent_pos.y}
		child_1_size := base.Vec2 {
			data.parent_width * data.child_1_pct_x,
			data.parent_height * data.child_1_pct_y,
		}

		child_2_pos := base.Vec2{child_1_pos.x, child_1_pos.y + child_1_size.y}

		child_2_size := base.Vec2 {
			data.parent_width * data.child_2_pct_x,
			data.parent_height * data.child_2_pct_y,
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "parent",
					pos = data.parent_pos,
					size = {data.parent_width, data.parent_height},
					children = []Expected_Element {
						{
							id = "child_1",
							pos = child_1_pos,
							size = child_1_size,
							children = []Expected_Element{},
						},
						{
							id = "child_2",
							pos = child_2_pos,
							size = child_2_size,
							children = []Expected_Element{},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_pct_of_parent_sizing_with_min_and_pref_width_grow_elments_inside :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		main_container_width:     f32,
		main_container_height:    f32,
		grouping_container_pct_x: f32,
		grouping_container_pct_y: f32,
		layout_direction:         Layout_Direction,
	}

	test_data := Test_Data {
		main_container_width     = 100,
		main_container_height    = 100,
		grouping_container_pct_x = 1.0,
		grouping_container_pct_y = 1.0,
		layout_direction         = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		main_container_sizing := [2]Sizing {
			{kind = .Fixed, value = data.main_container_width},
			{kind = .Fixed, value = data.main_container_height},
		}

		container(
			ctx,
			"main_container",
			Config_Options {
				layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				grouping_container_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = 1.0},
					{kind = .Percentage_Of_Parent, value = 1.0},
				}
				container(
					ctx,
					"grouping_container",
					Config_Options {
						layout = {
							sizing = {&grouping_container_sizing.x, &grouping_container_sizing.y},
						},
					},
					data,
					proc(ctx: ^Context, data: ^Test_Data) {
						first_child_sizing := [2]Sizing {
							{kind = .Grow, min_value = 50},
							{kind = .Grow},
						}
						container(
							ctx,
							"first_child",
							Config_Options {
								layout = {sizing = {&first_child_sizing.x, &first_child_sizing.y}},
							},
						)

						second_child_sizing := [2]Sizing {
							{kind = .Grow, value = 70},
							{kind = .Grow},
						}
						container(
							ctx,
							"second_child",
							Config_Options {
								layout = {
									sizing = {&second_child_sizing.x, &second_child_sizing.y},
								},
							},
						)
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		main_container_pos := base.Vec2{0, 0}
		main_container_size := base.Vec2{data.main_container_width, data.main_container_height}

		// Same pos as main container since no padding etc
		grouping_container_pos := main_container_pos
		grouping_container_size := base.Vec2 {
			main_container_size.x * data.grouping_container_pct_x,
			main_container_size.y * data.grouping_container_pct_y,
		}

		// Same pos as grouping container since no padding etc
		first_child_pos := grouping_container_pos
		first_child_size := base.Vec2{50, 100}

		second_child_pos := base.Vec2{first_child_pos.x + first_child_size.x, first_child_pos.y}
		second_child_size := base.Vec2{50, 100}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "main_container",
					pos = main_container_pos,
					size = main_container_size,
					children = []Expected_Element {
						{
							id = "grouping_container",
							pos = grouping_container_pos,
							size = grouping_container_size,
							children = []Expected_Element {
								{
									id = "first_child",
									pos = first_child_pos,
									size = first_child_size,
									children = []Expected_Element{},
								},
								{
									id = "second_child",
									pos = second_child_pos,
									size = second_child_size,
									children = []Expected_Element{},
								},
							},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_pct_of_parent_sizing_with_fit_sizing_element_inside :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		main_container_width:  f32,
		main_container_height: f32,
		panel_container_pct_x: f32,
		panel_container_pct_y: f32,
		fit_element_padding:   Padding,
		layout_direction:      Layout_Direction,
	}


	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		main_container_sizing := [2]Sizing {
			{kind = .Fixed, value = data.main_container_width},
			{kind = .Fixed, value = data.main_container_height},
		}

		container(
			ctx,
			"main_container",
			Config_Options {
				layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				panel_sizing := [2]Sizing {
					{kind = .Percentage_Of_Parent, value = data.panel_container_pct_x},
					{kind = .Percentage_Of_Parent, value = data.panel_container_pct_y},
				}

				container(
					ctx,
					"panel_container",
					Config_Options {
						layout = {
							sizing = {&panel_sizing.x, &panel_sizing.y},
							layout_direction = &data.layout_direction,
						},
					},
					data,
					proc(ctx: ^Context, data: ^Test_Data) {
						fit_element_sizing := Sizing {
							kind = .Fit,
						}
						container(
							ctx,
							"fit_element",
							Config_Options {
								layout = {
									sizing = {&fit_element_sizing, &fit_element_sizing},
									padding = &data.fit_element_padding,
								},
							},
						)
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		main_container_pos := base.Vec2{0, 0}
		main_container_size := base.Vec2{data.main_container_width, data.main_container_height}

		// Same pos as main container since no padding etc
		panel_container_pos := main_container_pos
		panel_container_size := base.Vec2 {
			main_container_size.x * data.panel_container_pct_y,
			main_container_size.y * data.panel_container_pct_y,
		}

		// Same pos as panel_container,
		fit_element_pos := panel_container_pos
		fit_element_size := base.Vec2 {
			data.fit_element_padding.left + data.fit_element_padding.right,
			data.fit_element_padding.top + data.fit_element_padding.bottom,
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "main_container",
					pos = main_container_pos,
					size = main_container_size,
					children = []Expected_Element {
						{
							id = "panel_container",
							pos = panel_container_pos,
							size = panel_container_size,
							children = []Expected_Element {
								{
									id = "fit_element",
									pos = fit_element_pos,
									size = fit_element_size,
									children = []Expected_Element{},
								},
							},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree.children[0])

	}

	// --- 4. Run the Tests ---
	// Left_To_Right test
	ltr_test_data := Test_Data {
		main_container_width  = 100,
		main_container_height = 100,
		panel_container_pct_x = 1.0,
		panel_container_pct_y = 1.0,
		fit_element_padding   = Padding{top = 20, right = 20, bottom = 20, left = 20},
		layout_direction      = .Left_To_Right,
	}

	run_ui_test(t, build_ui_proc, verify_proc, &ltr_test_data)

	// Top_To_Bottom test
	ttb_test_data := Test_Data {
		main_container_width  = 100,
		main_container_height = 100,
		panel_container_pct_x = 1.0,
		panel_container_pct_y = 1.0,
		fit_element_padding   = Padding{top = 20, right = 20, bottom = 20, left = 20},
		layout_direction      = .Top_To_Bottom,
	}

	run_ui_test(t, build_ui_proc, verify_proc, &ttb_test_data)
}

@(test)
test_pct_of_parent_sizing_with_fixed_container_and_grow_container_siblings :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:              base.Vec2,
		panel_layout_direction: Layout_Direction,
		main_container_size_y:  f32,
		container_1_pct:        f32,
		container_2_size:       base.Vec2,
	}

	test_data := Test_Data {
		root_size              = {500, 500},
		panel_layout_direction = .Left_To_Right,
		main_container_size_y  = 20,
		container_1_pct        = 0.1,
		container_2_size       = {20, 20},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		main_container_sizing := [2]Sizing {
			{kind = .Grow},
			{kind = .Fixed, value = data.main_container_size_y},
		}

		if begin_container(
			ctx,
			"main_container",
			{layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}}},
		) {

			container_1_sizing := [2]Sizing {
				{kind = .Percentage_Of_Parent, value = data.container_1_pct},
				{kind = .Grow},
			}

			container(
				ctx,
				"container_1",
				Config_Options{layout = {sizing = {&container_1_sizing.x, &container_1_sizing.y}}},
			)


			container_2_sizing := [2]Sizing {
				{kind = .Fixed, value = data.container_2_size.x},
				{kind = .Grow},
			}

			container(
				ctx,
				"container_2",
				Config_Options{layout = {sizing = {&container_2_sizing.x, &container_2_sizing.y}}},
			)

			container_3_sizing := [2]Sizing{{kind = .Grow}, {kind = .Grow}}
			container(
				ctx,
				"container_3",
				Config_Options{layout = {sizing = {&container_3_sizing.x, &container_3_sizing.y}}},
			)

			end_container(ctx)
		}
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		main_container_pos := root_pos
		main_container_size := base.Vec2{root_size.x, data.main_container_size_y}

		container_1_pos := main_container_pos
		container_1_size := base.Vec2 {
			main_container_size.x * data.container_1_pct,
			main_container_size.y,
		}

		container_2_pos := base.Vec2{container_1_pos.x + container_1_size.x, container_1_pos.y}
		container_2_size := data.container_2_size

		container_3_pos := base.Vec2{container_2_pos.x + container_2_size.x, container_2_pos.y}
		container_3_size := base.Vec2 {
			main_container_size.x - container_2_size.x - container_1_size.x,
			main_container_size.y,
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element {
				{
					id = "main_container",
					pos = main_container_pos,
					size = main_container_size,
					children = []Expected_Element {
						{id = "container_1", pos = container_1_pos, size = container_1_size},
						{id = "container_2", pos = container_2_pos, size = container_2_size},
						{id = "container_3", pos = container_3_pos, size = container_3_size},
					},
				},
			},
		}
		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)
}

@(test)
test_relative_layout_anchoring :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		root_size:   base.Vec2,
		parent_size: base.Vec2,
		child_size:  base.Vec2,
	}

	test_data := Test_Data {
		root_size   = {500, 500},
		parent_size = {200, 200},
		child_size  = {50, 50},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_mode := Layout_Mode.Relative

		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_size.x},
			{kind = .Fixed, value = data.parent_size.y},
		}

		if begin_container(
			ctx,
			"relative_parent",
			Config_Options {
				layout = {
					sizing = {&parent_sizing.x, &parent_sizing.y},
					layout_mode = &layout_mode,
				},
			},
		) {


			anchor_child :: proc(
				ctx: ^Context,
				id: string,
				child_sizing: [2]Sizing,
				alignment_x: Alignment_X,
				alignment_y: Alignment_Y,
			) {

				child_sizing := child_sizing

				child_alignment_x := alignment_x
				child_alignment_y := alignment_y

				container(
					ctx,
					id,
					Config_Options {
						layout = {
							sizing = {&child_sizing.x, &child_sizing.y},
							alignment_x = &child_alignment_x,
							alignment_y = &child_alignment_y,
						},
					},
				)
			}

			child_sizing := [2]Sizing {
				{kind = .Fixed, value = data.child_size.x},
				{kind = .Fixed, value = data.child_size.y},
			}

			// Top-Left
			anchor_child(ctx, "child_tl", child_sizing, Alignment_X.Left, Alignment_Y.Top)
			// Top-Right
			anchor_child(ctx, "child_tr", child_sizing, Alignment_X.Right, Alignment_Y.Top)
			// Bottom-Right
			anchor_child(ctx, "child_br", child_sizing, Alignment_X.Right, Alignment_Y.Bottom)
			// Bottom-Left
			anchor_child(ctx, "child_bl", child_sizing, Alignment_X.Left, Alignment_Y.Bottom)

			end_container(ctx)
		}
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}

		// Top-Left
		tl_pos := parent_pos

		// Top-Right
		tr_pos := parent_pos
		tr_pos.x += data.parent_size.x

		// Bottom-Right
		br_pos := parent_pos + data.parent_size

		// Bottom-Left
		bl_pos := parent_pos
		bl_pos.y += data.parent_size.y

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = data.root_size,
			children = []Expected_Element {
				{
					id = "relative_parent",
					pos = parent_pos,
					size = data.parent_size,
					children = []Expected_Element {
						{id = "child_tl", pos = tl_pos, size = data.child_size},
						{id = "child_tr", pos = tr_pos, size = data.child_size},
						{id = "child_br", pos = br_pos, size = data.child_size},
						{id = "child_bl", pos = bl_pos, size = data.child_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)
}


@(test)
test_relative_layout_with_offsets :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		root_size:   base.Vec2,
		parent_size: base.Vec2,
		child_size:  base.Vec2,
		offset_tl:   base.Vec2,
		offset_tr:   base.Vec2,
		offset_br:   base.Vec2,
		offset_bl:   base.Vec2,
	}

	test_data := Test_Data {
		root_size   = {500, 500},
		parent_size = {100, 100},
		child_size  = {20, 20},
		offset_tl   = {10, 15},
		offset_tr   = {-5, 10},
		offset_br   = {-5, -5},
		offset_bl   = {10, -5},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_mode := Layout_Mode.Relative

		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_size.x},
			{kind = .Fixed, value = data.parent_size.y},
		}

		if begin_container(
			ctx,
			"relative_parent",
			Config_Options {
				layout = {
					sizing = {&parent_sizing.x, &parent_sizing.y},
					layout_mode = &layout_mode,
				},
			},
		) {

			child_sizing := [2]Sizing {
				{kind = .Fixed, value = data.child_size.x},
				{kind = .Fixed, value = data.child_size.y},
			}

			offset_child :: proc(
				ctx: ^Context,
				id: string,
				child_sizing: [2]Sizing,
				align_x: Alignment_X,
				align_y: Alignment_Y,
				offset: base.Vec2,
			) {

				child_sizing := child_sizing
				align_x := align_x
				align_y := align_y
				offset := offset

				container(
					ctx,
					id,
					Config_Options {
						layout = {
							sizing = {&child_sizing.x, &child_sizing.y},
							alignment_x = &align_x,
							alignment_y = &align_y,
							relative_position = &offset,
						},
					},
				)

			}

			// Child 1: Top Left
			offset_child(
				ctx,
				"child_offset_tl",
				child_sizing,
				Alignment_X.Left,
				Alignment_Y.Top,
				data.offset_tl,
			)

			// Child 2: Top Right
			offset_child(
				ctx,
				"child_offset_tr",
				child_sizing,
				Alignment_X.Right,
				Alignment_Y.Top,
				data.offset_tr,
			)

			// Child 3: Bottom Right
			offset_child(
				ctx,
				"child_offset_br",
				child_sizing,
				Alignment_X.Right,
				Alignment_Y.Bottom,
				data.offset_br,
			)

			// Child 4: Bottom Left
			offset_child(
				ctx,
				"child_offset_bl",
				child_sizing,
				Alignment_X.Left,
				Alignment_Y.Bottom,
				data.offset_bl,
			)

			end_container(ctx)
		}
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}

		// Child Top-Left: Anchored at (0, 0)
		child_pos_tl := parent_pos + data.offset_tl

		// Child Top-Right
		child_pos_tr := parent_pos + data.offset_tr
		child_pos_tr.x += data.parent_size.x

		// Child Bottom-Right
		child_pos_br := parent_pos + data.parent_size + data.offset_br

		// Child Bottom-Left
		child_pos_bl := parent_pos + data.offset_bl
		child_pos_bl.y += data.parent_size.y

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = data.root_size,
			children = []Expected_Element {
				{
					id = "relative_parent",
					pos = parent_pos,
					size = data.parent_size,
					children = []Expected_Element {
						{id = "child_offset_tl", pos = child_pos_tl, size = data.child_size},
						{id = "child_offset_tr", pos = child_pos_tr, size = data.child_size},
						{id = "child_offset_br", pos = child_pos_br, size = data.child_size},
						{id = "child_offset_bl", pos = child_pos_bl, size = data.child_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)
}

@(test)
test_relative_layout_padding_influence :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		root_size:   base.Vec2,
		parent_size: base.Vec2,
		padding:     Padding,
		child_size:  base.Vec2,
	}

	test_data := Test_Data {
		root_size = {500, 500},
		parent_size = {100, 100},
		padding = {left = 10, right = 20, top = 5, bottom = 15},
		child_size = {20, 20},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_mode := Layout_Mode.Relative

		parent_sizing := [2]Sizing {
			{kind = .Fixed, value = data.parent_size.x},
			{kind = .Fixed, value = data.parent_size.y},
		}

		if begin_container(
			ctx,
			"relative_parent",
			Config_Options {
				layout = {
					sizing = {&parent_sizing.x, &parent_sizing.y},
					layout_mode = &layout_mode,
					padding = &data.padding,
				},
			},
		) {

			anchor_child :: proc(
				ctx: ^Context,
				id: string,
				sizing: [2]Sizing,
				align_x: Alignment_X,
				align_y: Alignment_Y,
			) {
				sizing := sizing
				align_x := align_x
				align_y := align_y

				container(
					ctx,
					id,
					Config_Options {
						layout = {
							sizing = {&sizing.x, &sizing.y},
							alignment_x = &align_x,
							alignment_y = &align_y,
						},
					},
				)
			}

			child_sizing := [2]Sizing {
				{kind = .Fixed, value = data.child_size.x},
				{kind = .Fixed, value = data.child_size.y},
			}

			// Top-Left
			anchor_child(ctx, "child_tl", child_sizing, .Left, .Top)

			// Top-Right
			anchor_child(ctx, "child_tr", child_sizing, .Right, .Top)

			// Bottom-Right
			anchor_child(ctx, "child_br", child_sizing, .Right, .Bottom)

			// Bottom-Left
			anchor_child(ctx, "child_bl", child_sizing, .Left, .Bottom)

			end_container(ctx)
		}

	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		// Content box size
		content_width := data.parent_size.x - data.padding.left - data.padding.right
		content_height := data.parent_size.y - data.padding.top - data.padding.bottom

		parent_pos := base.Vec2{0, 0}

		// Top-Left: Anchored to padding start
		child_pos_tl := parent_pos + base.Vec2{data.padding.left, data.padding.top}


		// Top-Right
		child_pos_tr := parent_pos + base.Vec2{data.padding.left + content_width, data.padding.top}

		// Bottom-Right
		child_pos_br :=
			parent_pos +
			base.Vec2{data.padding.left, data.padding.top} +
			base.Vec2{content_width, content_height}

		// Bottom-Left
		child_pos_bl :=
			parent_pos + base.Vec2{data.padding.left, data.padding.top + content_height}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = data.root_size,
			children = []Expected_Element {
				{
					id = "relative_parent",
					pos = parent_pos,
					size = data.parent_size,
					children = []Expected_Element {
						{id = "child_tl", pos = child_pos_tl, size = data.child_size},
						{id = "child_tr", pos = child_pos_tr, size = data.child_size},
						{id = "child_br", pos = child_pos_br, size = data.child_size},
						{id = "child_bl", pos = child_pos_bl, size = data.child_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)

	}

	// --- 4. Run the Test ---
	run_ui_test(
		t,
		build_ui_proc,
		verify_proc,
		&test_data,
		{i32(test_data.root_size.x), i32(test_data.root_size.y)},
	)
}
