package ui

import "core:testing"

import base "../base"


@(test)
test_fit_container_no_children :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding: Padding,
		panel_border:  Border,
	}

	test_data := Test_Data {
		panel_padding = Padding{left = 10, top = 20, right = 15, bottom = 25},
		panel_border = Border{left = 2, top = 2, right = 2, bottom = 2},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := Sizing {
			kind = .Fit,
		}
		layout_direction := Layout_Direction.Left_To_Right
		child_gap: f32 = 5
		container(
			ctx,
			"empty_panel",
			Style {
				sizing_x = sizing,
				sizing_y = sizing,
				layout_direction = layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = child_gap,
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
			data.panel_padding.left +
			data.panel_padding.right +
			data.panel_border.left +
			data.panel_border.right,
			data.panel_padding.top +
			data.panel_padding.bottom +
			data.panel_border.top +
			data.panel_border.bottom,
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
		panel_border:           Border,
		panel_child_gap:        f32,
		container_1_size:       base.Vec2,
		container_2_size:       base.Vec2,
		container_3_size:       base.Vec2,
		largest_container_y:    f32,
	}

	test_data := Test_Data {
		root_size = {500, 500},
		panel_layout_direction = .Left_To_Right,
		panel_sizing = {sizing_fit(), sizing_fit()},
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_border = Border{left = 5, top = 5, right = 5, bottom = 5},
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
			Style {
				sizing_x = data.panel_sizing.x,
				sizing_y = data.panel_sizing.y,
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_fixed(data.container_1_size.x),
						sizing_y = sizing_fixed(data.container_1_size.y),
					},
				)

				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_fixed(data.container_2_size.x),
						sizing_y = sizing_fixed(data.container_2_size.y),
					},
				)

				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
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
		panel_size_x :=
			data.panel_padding.left +
			data.panel_padding.right +
			data.panel_border.left +
			data.panel_border.right +
			data.panel_child_gap * 2 +
			data.container_1_size.x +
			data.container_2_size.x +
			data.container_3_size.x

		panel_size_y :=
			data.largest_container_y +
			data.panel_padding.top +
			data.panel_padding.bottom +
			data.panel_border.top +
			data.panel_border.bottom

		panel_size := base.Vec2{panel_size_x, panel_size_y}

		child_start_y := data.panel_padding.top + data.panel_border.top

		c1_pos_x := data.panel_padding.left + data.panel_border.left
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
							pos = {c1_pos_x, child_start_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, child_start_y},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, child_start_y},
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
		panel_border:           Border,
		panel_child_gap:        f32,
		container_1_size:       base.Vec2,
		container_2_size:       base.Vec2,
		container_3_size:       base.Vec2,
		largest_container_x:    f32,
	}
	test_data := Test_Data {
		root_size = {500, 500},
		panel_layout_direction = .Top_To_Bottom,
		panel_sizing = {sizing_fit(), sizing_fit()},
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_border = Border{left = 5, top = 5, right = 5, bottom = 5},
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
			Style {
				sizing_x = data.panel_sizing.x,
				sizing_y = data.panel_sizing.y,
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_fixed(data.container_1_size.x),
						sizing_y = sizing_fixed(data.container_1_size.y),
					},
				)

				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_fixed(data.container_2_size.x),
						sizing_y = sizing_fixed(data.container_2_size.y),
					},
				)

				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		panel_size_x :=
			data.largest_container_x +
			data.panel_padding.left +
			data.panel_padding.right +
			data.panel_border.left +
			data.panel_border.right

		panel_size_y :=
			data.panel_padding.top +
			data.panel_padding.bottom +
			data.panel_border.top +
			data.panel_border.bottom +
			data.panel_child_gap * 2 +
			data.container_1_size.y +
			data.container_2_size.y +
			data.container_3_size.y

		panel_size := base.Vec2{panel_size_x, panel_size_y}

		panel_pos := base.Vec2{0, 0}

		child_start_x := data.panel_padding.left + data.panel_border.left

		c1_pos_y := data.panel_padding.top + data.panel_border.top
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
							pos = {child_start_x, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {child_start_x, c2_pos_y},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {child_start_x, c3_pos_y},
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
		panel_border:           Border,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		container_1_size:       base.Vec2,
		container_3_size:       base.Vec2,
	}

	test_context := Test_Grow_Sizing_Ltr_Context {
		panel_layout_direction = .Left_To_Right,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_border = Border{left = 3, top = 3, right = 3, bottom = 3},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_fixed(data.container_1_size.x),
						sizing_y = sizing_fixed(data.container_1_size.y),
					},
				)

				container(
					ctx,
					"container_2",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				)

				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
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
		inner_panel_w :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right
		inner_panel_h :=
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom

		total_fixed_w := data.container_1_size.x + data.container_3_size.x
		total_gap_w := data.panel_child_gap * 2
		container_2_w := inner_panel_w - total_fixed_w - total_gap_w

		c1_pos_x := data.panel_padding.left + data.panel_border.left
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
							pos = {c1_pos_x, data.panel_padding.top + data.panel_border.top},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top + data.panel_border.top},
							size = {container_2_w, inner_panel_h},
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top + data.panel_border.top},
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
		panel_border:                 Border,
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
		panel_border = Border{left = 4, top = 4, right = 4, bottom = 4},
		panel_child_gap = 10,
		panel_size = base.Vec2{600, 400},
		container_1_max_value = 150,
		container_2_max_value = 50,
		container_3_size = base.Vec2{150, 150},
		container_3_layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_grow(max = data.container_1_max_value),
						sizing_y = sizing_grow(),
					},
				)
				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_grow(max = data.container_2_max_value),
						sizing_y = sizing_grow(),
					},
				)
				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		container_1_size := base.Vec2 {
			data.container_1_max_value,
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom,
		}

		container_2_size := base.Vec2 {
			data.container_2_max_value,
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom,
		}

		c1_pos_x := data.panel_padding.left + data.panel_border.left
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
							pos = {c1_pos_x, data.panel_padding.top + data.panel_border.top},
							size = container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top + data.panel_border.top},
							size = container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top + data.panel_border.top},
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
		panel_border:           Border,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		container_1_size:       base.Vec2,
		container_3_size:       base.Vec2,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_border = Border{left = 1, top = 2, right = 3, bottom = 4},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_fixed(data.container_1_size.x),
						sizing_y = sizing_fixed(data.container_1_size.y),
					},
				)
				container(
					ctx,
					"container_2",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		inner_panel_w :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right

		inner_panel_h :=
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom

		total_fixed_h := data.container_1_size.y + data.container_3_size.y
		total_gap_h := data.panel_child_gap * 2
		container_2_h := inner_panel_h - total_fixed_h - total_gap_h

		c1_pos_y := data.panel_padding.top + data.panel_border.top
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
							pos = {data.panel_padding.left + data.panel_border.left, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left + data.panel_border.left, c2_pos_y},
							size = {inner_panel_w, container_2_h},
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left + data.panel_border.left, c3_pos_y},
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
		panel_border:                 Border,
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
		panel_border = Border{left = 2, top = 3, right = 2, bottom = 3},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value = 100,
		container_2_max_value = 50,
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(max = data.container_1_max_value),
					},
				)
				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(max = data.container_2_max_value),
					},
				)
				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_fixed(data.container_3_size.x),
						sizing_y = sizing_fixed(data.container_3_size.y),
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		container_1_size := base.Vec2 {
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right,
			data.container_1_max_value,
		}

		container_2_size := base.Vec2 {
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right,
			data.container_2_max_value,
		}

		c1_pos_y := data.panel_padding.top + data.panel_border.top
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
							pos = {data.panel_padding.left + data.panel_border.left, c1_pos_y},
							size = container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left + data.panel_border.left, c2_pos_y},
							size = container_2_size,
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left + data.panel_border.left, c3_pos_y},
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
		panel_border:            Border,
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
		panel_border = Border{left = 6, top = 6, right = 6, bottom = 6},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value_x = 100,
		container_1_max_value_y = 100,
		container_2_max_value_y = 75,
		container_3_max_value_x = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_grow(max = data.container_1_max_value_x),
						sizing_y = sizing_grow(max = data.container_1_max_value_y),
					},
				)

				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(max = data.container_2_max_value_y),
					},
				)

				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_grow(max = data.container_3_max_value_x),
						sizing_y = sizing_grow(),
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {

		// --- Primary Axis Calculation (X-axis) ---
		num_children := 3
		panel_inner_width :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right
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
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom
		c1_final_y := min(panel_inner_height, data.container_1_max_value_y)
		c2_final_y := min(panel_inner_height, data.container_2_max_value_y)
		c3_final_y := panel_inner_height

		// --- Final Sizes and Positions
		c1_size := base.Vec2{c1_final_x, c1_final_y}
		c2_size := base.Vec2{c2_final_x, c2_final_y}
		c3_size := base.Vec2{c3_final_x, c3_final_y}

		c1_pos := base.Vec2 {
			data.panel_padding.left + data.panel_border.left,
			data.panel_padding.top + data.panel_border.top,
		}
		c2_pos := base.Vec2 {
			c1_pos.x + c1_size.x + data.panel_child_gap,
			data.panel_padding.top + data.panel_border.top,
		}
		c3_pos := base.Vec2 {
			c2_pos.x + c2_size.x + data.panel_child_gap,
			data.panel_padding.top + data.panel_border.top,
		}

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
		panel_border:            Border,
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
		panel_border = Border{left = 7, top = 8, right = 9, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_max_value_x = 100,
		container_1_max_value_y = 100,
		container_2_max_value_x = 75,
		container_3_max_value_y = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				container(
					ctx,
					"container_1",
					Style {
						sizing_x = sizing_grow(max = data.container_1_max_value_x),
						sizing_y = sizing_grow(max = data.container_1_max_value_y),
					},
				)

				container(
					ctx,
					"container_2",
					Style {
						sizing_x = sizing_grow(max = data.container_2_max_value_x),
						sizing_y = sizing_grow(),
					},
				)

				container(
					ctx,
					"container_3",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(max = data.container_3_max_value_y),
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
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom
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
		panel_inner_width :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right
		c1_final_x := min(panel_inner_width, data.container_1_max_value_x)
		c2_final_x := min(panel_inner_width, data.container_2_max_value_x)
		c3_final_x := panel_inner_width

		// --- Final Sizes and Positions
		c1_size := base.Vec2{c1_final_x, c1_final_y}
		c2_size := base.Vec2{c2_final_x, c2_final_y}
		c3_size := base.Vec2{c3_final_x, c3_final_y}

		c1_pos := base.Vec2 {
			data.panel_padding.left + data.panel_border.left,
			data.panel_padding.top + data.panel_border.top,
		}
		c2_pos := base.Vec2 {
			data.panel_padding.left + data.panel_border.left,
			c1_pos.y + c1_size.y + data.panel_child_gap,
		}
		c3_pos := base.Vec2 {
			data.panel_padding.left + data.panel_border.left,
			c2_pos.y + c2_size.y + data.panel_child_gap,
		}

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
test_grow_sizing_equal_factors_reach_equal_size_ltr :: proc(t: ^testing.T) {
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
		container(
			ctx,
			"parent",
			Style {
				sizing_x = Sizing{kind = .Fixed, value = data.parent_width},
				sizing_y = Sizing{kind = .Fixed, value = data.parent_height},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"child_1",
					Style{sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()},
				)

				container(
					ctx,
					"child_2",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
				)
			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}
		parent_size := base.Vec2{data.parent_width, data.parent_height}

		// With target-based distribution: equal factors = equal sizes
		// Total factor = 2, available = 100
		// Target for each = 100 / 2 = 50
		// child_1 min=50, target=50 → 50
		// child_2 min=0, target=50 → 50
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
		panel_border:           Border,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		text_1_min_width:       f32,
		grow_box_min_width:     f32,
		text_2_min_width:       f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Left_To_Right,
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_border = Border{left = 3, top = 4, right = 5, bottom = 6},
		panel_child_gap = 10,
		panel_size = {300, 100},
		text_1_min_width = 10,
		grow_box_min_width = 5,
		text_2_min_width = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				text(
					ctx,
					"text_1",
					"First",
					Style {
						sizing_x = sizing_grow(min = data.text_1_min_width),
						sizing_y = sizing_grow(),
					},
				)

				container(
					ctx,
					"grow_box",
					Style {
						sizing_x = sizing_grow(min = data.grow_box_min_width),
						sizing_y = sizing_grow(),
					},
				)

				text(
					ctx,
					"text_2",
					"Last",
					Style {
						sizing_x = sizing_grow(min = data.text_2_min_width),
						sizing_y = sizing_grow(),
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
			data.panel_border.left -
			data.panel_border.right -
			2 * data.panel_child_gap

		expected_child_height :=
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			data.panel_border.top -
			data.panel_border.bottom

		// With target-based distribution: equal factors = equal sizes
		// Available = 252, 3 elements with factor 1 each
		// Target for each = 252 / 3 = 84
		text_1_width: f32 = available_width / 3
		grow_box_width: f32 = available_width / 3
		text_2_width: f32 = available_width / 3

		c1_pos_x := data.panel_padding.left + data.panel_border.left
		c2_pos_x := c1_pos_x + text_1_width + data.panel_child_gap
		c3_pos_x := c2_pos_x + grow_box_width + data.panel_child_gap


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
							pos = {c1_pos_x, data.panel_padding.top + data.panel_border.top},
							size = {text_1_width, expected_child_height},
						},
						{
							id = "grow_box",
							pos = {c2_pos_x, data.panel_padding.top + data.panel_border.top},
							size = {grow_box_width, expected_child_height},
						},
						{
							id = "text_2",
							pos = {c3_pos_x, data.panel_padding.top + data.panel_border.top},
							size = {text_2_width, expected_child_height},
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
		panel_border:           Border,
		panel_child_gap:        f32,
		panel_size:             base.Vec2,
		text_1_min_height:      f32,
		grow_box_min_height:    f32,
		text_2_min_height:      f32,
	}

	test_data := Test_Data {
		panel_layout_direction = .Top_To_Bottom,
		panel_padding = {left = 10, top = 11, right = 12, bottom = 13},
		panel_border = Border{left = 2, top = 2, right = 2, bottom = 2},
		panel_child_gap = 10,
		panel_size = {100, 100},
		text_1_min_height = 10,
		grow_box_min_height = 5,
		text_2_min_height = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = data.panel_layout_direction,
				padding = data.panel_padding,
				border = data.panel_border,
				child_gap = data.panel_child_gap,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text_1",
					"First",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(min = data.text_1_min_height),
					},
				)

				container(
					ctx,
					"grow_box",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(min = data.grow_box_min_height),
					},
				)

				text(
					ctx,
					"text_2",
					"Last",
					Style {
						sizing_x = sizing_grow(),
						sizing_y = sizing_grow(min = data.text_1_min_height),
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
			data.panel_border.top -
			data.panel_border.bottom -
			2 * data.panel_child_gap

		expected_child_width :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			data.panel_border.left -
			data.panel_border.right

		// With target-based distribution: equal factors = equal sizes
		// Available = 52, 3 elements with factor 1 each
		// Target for each = 52 / 3 = 17.333...
		text_1_height: f32 = available_height / 3
		grow_box_height: f32 = available_height / 3
		text_2_height: f32 = available_height / 3

		c1_pos_y := data.panel_padding.top + data.panel_border.top
		c2_pos_y := c1_pos_y + text_1_height + data.panel_child_gap
		c3_pos_y := c2_pos_y + grow_box_height + data.panel_child_gap

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
							pos = {data.panel_padding.left + data.panel_border.left, c1_pos_y},
							size = {expected_child_width, text_1_height},
						},
						{
							id = "grow_box",
							pos = {data.panel_padding.left + data.panel_border.left, c2_pos_y},
							size = {expected_child_width, grow_box_height},
						},
						{
							id = "text_2",
							pos = {data.panel_padding.left + data.panel_border.left, c3_pos_y},
							size = {expected_child_width, text_2_height},
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
test_basic_percentage_of_parent_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		parent_pos:       base.Vec2,
		parent_padding:   Padding,
		parent_border:    Border,
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
		parent_width = 100,
		parent_height = 100,
		parent_pos = {0, 0},
		parent_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		parent_border = Border{left = 2, top = 2, right = 2, bottom = 2},
		child_gap = 0,
		child_1_pct_x = 0.5,
		child_1_pct_y = 0.5,
		child_2_pct_x = 0.5,
		child_2_pct_y = 0.5,
		child_3_pct_x = 0,
		child_3_pct_y = 0,
		layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"parent",
			Style {
				sizing_x = Sizing{kind = .Fixed, value = data.parent_width},
				sizing_y = Sizing{kind = .Fixed, value = data.parent_height},
				layout_direction = data.layout_direction,
				padding = data.parent_padding,
				border = data.parent_border,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				// Child 1
				container(
					ctx,
					"child_1",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = data.child_1_pct_x},
						sizing_y = Sizing{kind = .Percentage, value = data.child_1_pct_y},
					},
				)

				// Child 2
				container(
					ctx,
					"child_2",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = data.child_2_pct_x},
						sizing_y = Sizing{kind = .Percentage, value = data.child_2_pct_y},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		inner_width :=
			data.parent_width -
			data.parent_padding.left -
			data.parent_padding.right -
			data.parent_border.left -
			data.parent_border.right
		inner_height :=
			data.parent_height -
			data.parent_padding.top -
			data.parent_padding.bottom -
			data.parent_border.top -
			data.parent_border.bottom

		child_1_pos := base.Vec2 {
			data.parent_pos.x + data.parent_padding.left + data.parent_border.left,
			data.parent_pos.y + data.parent_padding.top + data.parent_border.top,
		}
		child_1_size := base.Vec2 {
			inner_width * data.child_1_pct_x,
			inner_height * data.child_1_pct_y,
		}

		child_2_pos := base.Vec2{child_1_pos.x + child_1_size.x, child_1_pos.y}

		child_2_size := base.Vec2 {
			inner_width * data.child_2_pct_x,
			inner_height * data.child_2_pct_y,
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
		parent_padding:   Padding,
		parent_border:    Border,
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
		parent_width = 100,
		parent_height = 100,
		parent_pos = {0, 0},
		parent_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		parent_border = Border{left = 3, top = 3, right = 3, bottom = 3},
		child_gap = 0,
		child_1_pct_x = 0.5,
		child_1_pct_y = 0.5,
		child_2_pct_x = 0.5,
		child_2_pct_y = 0.5,
		child_3_pct_x = 0,
		child_3_pct_y = 0,
		layout_direction = .Top_To_Bottom,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"parent",
			Style {
				sizing_x = Sizing{kind = .Fixed, value = data.parent_width},
				sizing_y = Sizing{kind = .Fixed, value = data.parent_height},
				layout_direction = data.layout_direction,
				padding = data.parent_padding,
				border = data.parent_border,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				// Child 1
				container(
					ctx,
					"child_1",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = data.child_1_pct_x},
						sizing_y = Sizing{kind = .Percentage, value = data.child_1_pct_y},
					},
				)

				// Child 2
				container(
					ctx,
					"child_2",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = data.child_2_pct_x},
						sizing_y = Sizing{kind = .Percentage, value = data.child_2_pct_y},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		inner_width :=
			data.parent_width -
			data.parent_padding.left -
			data.parent_padding.right -
			data.parent_border.left -
			data.parent_border.right
		inner_height :=
			data.parent_height -
			data.parent_padding.top -
			data.parent_padding.bottom -
			data.parent_border.top -
			data.parent_border.bottom

		child_1_pos := base.Vec2 {
			data.parent_pos.x + data.parent_padding.left + data.parent_border.left,
			data.parent_pos.y + data.parent_padding.top + data.parent_border.top,
		}
		child_1_size := base.Vec2 {
			inner_width * data.child_1_pct_x,
			inner_height * data.child_1_pct_y,
		}

		child_2_pos := base.Vec2{child_1_pos.x, child_1_pos.y + child_1_size.y}

		child_2_size := base.Vec2 {
			inner_width * data.child_2_pct_x,
			inner_height * data.child_2_pct_y,
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
		main_container_padding:   Padding,
		main_container_border:    Border,
		grouping_container_pct_x: f32,
		grouping_container_pct_y: f32,
		layout_direction:         Layout_Direction,
	}

	test_data := Test_Data {
		main_container_width = 100,
		main_container_height = 100,
		main_container_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		main_container_border = Border{left = 1, top = 1, right = 1, bottom = 1},
		grouping_container_pct_x = 1.0,
		grouping_container_pct_y = 1.0,
		layout_direction = .Left_To_Right,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"main_container",
			Style {
				sizing_x = Sizing{kind = .Fixed, value = data.main_container_width},
				sizing_y = Sizing{kind = .Fixed, value = data.main_container_height},
				padding = data.main_container_padding,
				border = data.main_container_border,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"grouping_container",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = 1.0},
						sizing_y = Sizing{kind = .Percentage, value = 1.0},
					},
					data,
					proc(ctx: ^Context, data: ^Test_Data) {
						container(
							ctx,
							"first_child",
							Style{sizing_x = sizing_grow(min = 50), sizing_y = sizing_grow()},
						)

						container(
							ctx,
							"second_child",
							Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
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

		main_inner_width :=
			data.main_container_width -
			data.main_container_padding.left -
			data.main_container_padding.right -
			data.main_container_border.left -
			data.main_container_border.right
		main_inner_height :=
			data.main_container_height -
			data.main_container_padding.top -
			data.main_container_padding.bottom -
			data.main_container_border.top -
			data.main_container_border.bottom

		grouping_container_pos := base.Vec2 {
			main_container_pos.x +
			data.main_container_padding.left +
			data.main_container_border.left,
			main_container_pos.y +
			data.main_container_padding.top +
			data.main_container_border.top,
		}
		grouping_container_size := base.Vec2 {
			main_inner_width * data.grouping_container_pct_x,
			main_inner_height * data.grouping_container_pct_y,
		}

		// Same pos as grouping container since no padding etc
		first_child_pos := grouping_container_pos
		// With target-based distribution: equal factors = equal target sizes
		// Available = 98, target for each = 49
		// first_child min=50 > 49, so clamped to 50
		// Remaining for second_child = 98 - 50 = 48
		first_child_size := base.Vec2{50, grouping_container_size.y}

		second_child_pos := base.Vec2{first_child_pos.x + first_child_size.x, first_child_pos.y}
		second_child_size := base.Vec2{48, grouping_container_size.y}

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
		main_container_width:   f32,
		main_container_height:  f32,
		main_container_padding: Padding,
		main_container_border:  Border,
		panel_container_pct_x:  f32,
		panel_container_pct_y:  f32,
		fit_element_padding:    Padding,
		layout_direction:       Layout_Direction,
	}


	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		container(
			ctx,
			"main_container",
			Style {
				sizing_x = Sizing{kind = .Fixed, value = data.main_container_width},
				sizing_y = Sizing{kind = .Fixed, value = data.main_container_height},
				padding = data.main_container_padding,
				border = data.main_container_border,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"panel_container",
					Style {
						sizing_x = Sizing{kind = .Percentage, value = data.panel_container_pct_x},
						sizing_y = Sizing{kind = .Percentage, value = data.panel_container_pct_y},
						layout_direction = data.layout_direction,
					},
					data,
					proc(ctx: ^Context, data: ^Test_Data) {
						fit_element_sizing := Sizing {
							kind = .Fit,
						}
						container(
							ctx,
							"fit_element",
							Style {
								sizing_x = fit_element_sizing,
								sizing_y = fit_element_sizing,
								padding = data.fit_element_padding,
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

		main_inner_width :=
			data.main_container_width -
			data.main_container_padding.left -
			data.main_container_padding.right -
			data.main_container_border.left -
			data.main_container_border.right
		main_inner_height :=
			data.main_container_height -
			data.main_container_padding.top -
			data.main_container_padding.bottom -
			data.main_container_border.top -
			data.main_container_border.bottom

		panel_container_pos := base.Vec2 {
			main_container_pos.x +
			data.main_container_padding.left +
			data.main_container_border.left,
			main_container_pos.y +
			data.main_container_padding.top +
			data.main_container_border.top,
		}
		panel_container_size := base.Vec2 {
			main_inner_width * data.panel_container_pct_y,
			main_inner_height * data.panel_container_pct_y,
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
		main_container_width = 100,
		main_container_height = 100,
		main_container_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		main_container_border = Border{left = 2, top = 2, right = 2, bottom = 2},
		panel_container_pct_x = 1.0,
		panel_container_pct_y = 1.0,
		fit_element_padding = Padding{top = 20, right = 20, bottom = 20, left = 20},
		layout_direction = .Left_To_Right,
	}

	run_ui_test(t, build_ui_proc, verify_proc, &ltr_test_data)

	// Top_To_Bottom test
	ttb_test_data := Test_Data {
		main_container_width = 100,
		main_container_height = 100,
		main_container_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		main_container_border = Border{left = 2, top = 2, right = 2, bottom = 2},
		panel_container_pct_x = 1.0,
		panel_container_pct_y = 1.0,
		fit_element_padding = Padding{top = 20, right = 20, bottom = 20, left = 20},
		layout_direction = .Top_To_Bottom,
	}

	run_ui_test(t, build_ui_proc, verify_proc, &ttb_test_data)
}


@(test)
test_pct_of_parent_sizing_with_fixed_container_and_grow_container_siblings :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:              base.Vec2,
		panel_layout_direction: Layout_Direction,
		main_container_padding: Padding,
		main_container_border:  Border,
		main_container_size_y:  f32,
		container_1_pct:        f32,
		container_2_size:       base.Vec2,
	}

	test_data := Test_Data {
		root_size = {500, 500},
		panel_layout_direction = .Left_To_Right,
		main_container_padding = Padding{left = 0, top = 0, right = 0, bottom = 0},
		main_container_border = Border{left = 1, top = 1, right = 1, bottom = 1},
		main_container_size_y = 20,
		container_1_pct = 0.1,
		container_2_size = {20, 20},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		if begin_container(
			ctx,
			"main_container",
			Style {
				sizing_x = sizing_grow(),
				sizing_y = Sizing{kind = .Fixed, value = data.main_container_size_y},
				padding = data.main_container_padding,
				border = data.main_container_border,
			},
		) {

			container(
				ctx,
				"container_1",
				Style {
					sizing_x = Sizing{kind = .Percentage, value = data.container_1_pct},
					sizing_y = sizing_grow(),
				},
			)


			container(
				ctx,
				"container_2",
				Style{sizing_x = sizing_fixed(data.container_2_size.x), sizing_y = sizing_grow()},
			)

			container(
				ctx,
				"container_3",
				Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
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

		main_inner_width :=
			main_container_size.x -
			data.main_container_padding.left -
			data.main_container_padding.right -
			data.main_container_border.left -
			data.main_container_border.right
		main_inner_height :=
			main_container_size.y -
			data.main_container_padding.top -
			data.main_container_padding.bottom -
			data.main_container_border.top -
			data.main_container_border.bottom

		container_1_pos := base.Vec2 {
			main_container_pos.x +
			data.main_container_padding.left +
			data.main_container_border.left,
			main_container_pos.y +
			data.main_container_padding.top +
			data.main_container_border.top,
		}
		container_1_size := base.Vec2{main_inner_width * data.container_1_pct, main_inner_height}

		container_2_pos := base.Vec2{container_1_pos.x + container_1_size.x, container_1_pos.y}
		container_2_size := base.Vec2{data.container_2_size.x, main_inner_height}

		container_3_pos := base.Vec2{container_2_pos.x + container_2_size.x, container_2_pos.y}
		container_3_size := base.Vec2 {
			main_inner_width - container_2_size.x - container_1_size.x,
			main_inner_height,
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
test_fit_sizing_respects_max_size_constraint :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:        base.Vec2,
		container_sizing: [2]Sizing,
		child_size:       base.Vec2,
	}

	test_data := Test_Data {
		root_size        = {500, 500},
		// Container with .Fit sizing but max_size of 100x100
		// Child will be 300x300, so container should be clamped to 100x100
		container_sizing = {
			Sizing{kind = .Fit, max_value = 100},
			Sizing{kind = .Fit, max_value = 100},
		},
		child_size       = {300, 300},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_direction := Layout_Direction.Left_To_Right

		begin_container(
			ctx,
			"fit_container",
			Style {
				sizing_x = data.container_sizing.x,
				sizing_y = data.container_sizing.y,
				layout_direction = layout_direction,
			},
		)
		{
			// Add a child that is 300x300, which exceeds the parent's max of 100x100
			container(
				ctx,
				"large_child",
				Style {
					sizing_x = Sizing{kind = .Fixed, value = data.child_size.x},
					sizing_y = Sizing{kind = .Fixed, value = data.child_size.y},
				},
			)
		}
		end_container(ctx)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		// The container should be clamped to max_size (100x100), NOT the child size (300x300)
		container_pos := base.Vec2{0, 0}
		container_size := base.Vec2{100, 100}

		child_pos := base.Vec2{0, 0}
		child_size := data.child_size

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element {
				{
					id = "fit_container",
					pos = container_pos,
					size = container_size,
					children = []Expected_Element {
						{id = "large_child", pos = child_pos, size = child_size},
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
test_fit_sizing_respects_min_size_constraint :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:        base.Vec2,
		container_sizing: [2]Sizing,
		child_size:       base.Vec2,
	}

	test_data := Test_Data {
		root_size        = {500, 500},
		// Container with .Fit sizing but min_size of 200x200
		// Child will be 50x50, so container should be clamped to 200x200
		container_sizing = {
			Sizing{kind = .Fit, min_value = 200},
			Sizing{kind = .Fit, min_value = 200},
		},
		child_size       = {50, 50},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_direction := Layout_Direction.Left_To_Right

		begin_container(
			ctx,
			"fit_container",
			Style {
				sizing_x = data.container_sizing.x,
				sizing_y = data.container_sizing.y,
				layout_direction = layout_direction,
			},
		)
		{
			// Add a small child (50x50), which is less than the parent's min of 200x200
			container(
				ctx,
				"small_child",
				Style {
					sizing_x = Sizing{kind = .Fixed, value = data.child_size.x},
					sizing_y = Sizing{kind = .Fixed, value = data.child_size.y},
				},
			)
		}
		end_container(ctx)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		root_pos := base.Vec2{0, 0}
		root_size := data.root_size

		// The container should be clamped to min_size (200x200), NOT the child size (50x50)
		container_pos := base.Vec2{0, 0}
		container_size := base.Vec2{200, 200}

		// The child keeps its fixed size of 50x50
		child_pos := base.Vec2{0, 0}
		child_size := data.child_size

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = root_pos,
			size     = root_size,
			children = []Expected_Element {
				{
					id = "fit_container",
					pos = container_pos,
					size = container_size,
					children = []Expected_Element {
						{id = "small_child", pos = child_pos, size = child_size},
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
test_text_element_size_includes_border :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		root_size:   base.Vec2,
		text_string: string,
		padding:     Padding,
		border:      Border,
	}

	test_data := Test_Data {
		root_size = {500, 500},
		text_string = "Button",
		padding = Padding{left = 12, top = 8, right = 12, bottom = 8},
		border = Border{left = 2, top = 2, right = 2, bottom = 2},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"wrapper",
			Style{sizing_x = sizing_fit(), sizing_y = sizing_fit()},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				button(
					ctx,
					"test_button",
					data.text_string,
					Style{padding = data.padding, border = data.border},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Calculate expected size:
		text_width: f32 = 6 * MOCK_LINE_HEIGHT // "Button" = 6 chars
		text_height: f32 = MOCK_LINE_HEIGHT

		// Expected button size should include text + padding + border
		expected_width :=
			text_width +
			data.padding.left +
			data.padding.right +
			data.border.left +
			data.border.right

		expected_height :=
			text_height +
			data.padding.top +
			data.padding.bottom +
			data.border.top +
			data.border.bottom

		// The wrapper container with .Fit sizing should shrink-wrap to the button size
		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = data.root_size,
			children = []Expected_Element {
				{
					id = "wrapper",
					pos = {0, 0},
					size = {expected_width, expected_height},
					children = []Expected_Element {
						{
							id = "test_button",
							pos = {0, 0},
							size = {expected_width, expected_height},
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
test_grow_equal_factors :: proc(t: ^testing.T) {
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {300, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(ctx, "c1", Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()})
				container(ctx, "c2", Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()})
				container(ctx, "c3", Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()})
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {100, 100}},
					{id = "c2", pos = {100, 0}, size = {100, 100}},
					{id = "c3", pos = {200, 0}, size = {100, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_weighted_factors :: proc(t: ^testing.T) {
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {400, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_grow_weighted(2), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c3",
					Style{sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {100, 100}},
					{id = "c2", pos = {100, 0}, size = {200, 100}},
					{id = "c3", pos = {300, 0}, size = {100, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_shrink_proportional_to_factor :: proc(t: ^testing.T) {
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {240, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_fixed(100, 0), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_fixed(200, 0), sizing_y = sizing_grow()},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Fixed sizing doesn't participate in shrink, so children keep their sizes
		// The panel just doesn't have enough space, but fixed children don't shrink
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {100, 100}},
					{id = "c2", pos = {100, 0}, size = {200, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_shrink_grow_elements :: proc(t: ^testing.T) {
	// Test shrink behavior with Grow elements
	// Two grow elements with equal grow_factor split the space equally
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {240, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(ctx, "c1", Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()})
				container(ctx, "c2", Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()})
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Both grow elements split the space equally
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {120, 100}},
					{id = "c2", pos = {120, 0}, size = {120, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_zero_grow_factor_excluded :: proc(t: ^testing.T) {
	// Test that factor=0 child doesn't participate in grow distribution
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {400, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c3",
					Style{sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// c2 with factor=0 stays at 0, c1 and c3 split the 400px equally
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {200, 100}},
					{id = "c2", pos = {200, 0}, size = {0, 100}},
					{id = "c3", pos = {200, 0}, size = {200, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_weighted_grow_with_max_constraint :: proc(t: ^testing.T) {
	// Test weighted grow where one child hits max constraint
	// factors [1,1], 400px, but c1 has max=100
	// c1 gets 100 (hits max), remaining 300px goes to c2
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {400, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_grow_weighted(1, 0, 100), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_grow_weighted(1), sizing_y = sizing_grow()},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// c1 hits max at 100, c2 gets the rest (300)
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {100, 100}},
					{id = "c2", pos = {100, 0}, size = {300, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_all_zero_factors :: proc(t: ^testing.T) {
	// Test edge case: all factors are 0, no distribution should happen
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {400, 100},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Left_To_Right,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_grow_weighted(0), sizing_y = sizing_grow()},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Both have factor=0, so no grow distribution; they stay at initial size (0)
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {0, 100}},
					{id = "c2", pos = {0, 0}, size = {0, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_weighted_grow_ttb :: proc(t: ^testing.T) {
	// Test weighted distribution on Y axis (Top_To_Bottom layout)
	Test_Data :: struct {
		panel_size: base.Vec2,
	}
	test_data := Test_Data {
		panel_size = {100, 400},
	}

	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			Style {
				sizing_x = sizing_fixed(data.panel_size.x),
				sizing_y = sizing_fixed(data.panel_size.y),
				layout_direction = .Top_To_Bottom,
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"c1",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)},
				)
				container(
					ctx,
					"c2",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(2)},
				)
				container(
					ctx,
					"c3",
					Style{sizing_x = sizing_grow(), sizing_y = sizing_grow_weighted(1)},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// factors [1,2,1] on Y axis, 400px => [100, 200, 100]
		expect_layout(
			t,
			ctx,
			root,
			Expected_Element {
				id = "panel",
				pos = {0, 0},
				size = data.panel_size,
				children = []Expected_Element {
					{id = "c1", pos = {0, 0}, size = {100, 100}},
					{id = "c2", pos = {0, 100}, size = {100, 200}},
					{id = "c3", pos = {0, 300}, size = {100, 100}},
				},
			},
		)
	}

	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}
