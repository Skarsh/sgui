package ui

import "core:testing"

import base "../base"


@(test)
test_margin_spacing_between_siblings_ltr :: proc(t: ^testing.T) {
	// Test that margins create space between siblings in Left-To-Right layout
	// and do NOT reduce the parent's available content size

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		parent_size:    base.Vec2,
		parent_padding: Padding,
		child_1_size:   base.Vec2,
		child_1_margin: Margin,
		child_2_size:   base.Vec2,
		child_2_margin: Margin,
		child_3_size:   base.Vec2,
		child_3_margin: Margin,
	}

	test_data := Test_Data {
		parent_size = {500, 200},
		parent_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		child_1_size = {100, 50},
		child_1_margin = Margin{left = 5, top = 5, right = 10, bottom = 5},
		child_2_size = {80, 60},
		child_2_margin = Margin{left = 15, top = 8, right = 15, bottom = 8},
		child_3_size = {120, 70},
		child_3_margin = Margin{left = 20, top = 10, right = 5, bottom = 10},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		begin_container(
			ctx,
			"parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_direction = .Left_To_Right,
				padding = data.parent_padding,
			},
		)

		// Child 1
		container(
			ctx,
			"child_1",
			Style {
				sizing_x = sizing_fixed(data.child_1_size.x),
				sizing_y = sizing_fixed(data.child_1_size.y),
				margin = data.child_1_margin,
			},
		)

		// Child 2
		container(
			ctx,
			"child_2",
			Style {
				sizing_x = sizing_fixed(data.child_2_size.x),
				sizing_y = sizing_fixed(data.child_2_size.y),
				margin = data.child_2_margin,
			},
		)

		// Child 3
		container(
			ctx,
			"child_3",
			Style {
				sizing_x = sizing_fixed(data.child_3_size.x),
				sizing_y = sizing_fixed(data.child_3_size.y),
				margin = data.child_3_margin,
			},
		)

		end_container(ctx)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Parent position and size
		parent_pos := base.Vec2{0, 0}
		parent_size := data.parent_size

		// Calculate content area (margins should NOT reduce this)
		content_start_x := parent_pos.x + data.parent_padding.left
		content_start_y := parent_pos.y + data.parent_padding.top

		// Child 1: positioned with left margin from content start
		child_1_pos := base.Vec2 {
			content_start_x + data.child_1_margin.left,
			content_start_y + data.child_1_margin.top,
		}

		// Child 2: positioned after child 1 (child_1 size + child_1 right margin + child_2 left margin)
		child_2_pos_x :=
			child_1_pos.x +
			data.child_1_size.x +
			data.child_1_margin.right +
			data.child_2_margin.left
		child_2_pos := base.Vec2{child_2_pos_x, content_start_y + data.child_2_margin.top}

		// Child 3: positioned after child 2
		child_3_pos_x :=
			child_2_pos.x +
			data.child_2_size.x +
			data.child_2_margin.right +
			data.child_3_margin.left
		child_3_pos := base.Vec2{child_3_pos_x, content_start_y + data.child_3_margin.top}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = {f32(DEFAULT_TESTING_WINDOW_SIZE.x), f32(DEFAULT_TESTING_WINDOW_SIZE.y)},
			children = []Expected_Element {
				{
					id = "parent",
					pos = parent_pos,
					size = parent_size,
					children = []Expected_Element {
						{id = "child_1", pos = child_1_pos, size = data.child_1_size},
						{id = "child_2", pos = child_2_pos, size = data.child_2_size},
						{id = "child_3", pos = child_3_pos, size = data.child_3_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_margin_spacing_between_siblings_ttb :: proc(t: ^testing.T) {
	// Test that margins create space between siblings in Top-To-Bottom layout

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		parent_size:    base.Vec2,
		parent_padding: Padding,
		child_1_size:   base.Vec2,
		child_1_margin: Margin,
		child_2_size:   base.Vec2,
		child_2_margin: Margin,
	}

	test_data := Test_Data {
		parent_size = {300, 400},
		parent_padding = Padding{left = 15, top = 15, right = 15, bottom = 15},
		child_1_size = {100, 80},
		child_1_margin = Margin{left = 5, top = 10, right = 5, bottom = 20},
		child_2_size = {120, 60},
		child_2_margin = Margin{left = 8, top = 25, right = 8, bottom = 10},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		begin_container(
			ctx,
			"parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_direction = .Top_To_Bottom,
				padding = data.parent_padding,
			},
		)

		// Child 1
		container(
			ctx,
			"child_1",
			Style {
				sizing_x = sizing_fixed(data.child_1_size.x),
				sizing_y = sizing_fixed(data.child_1_size.y),
				margin = data.child_1_margin,
			},
		)

		// Child 2
		container(
			ctx,
			"child_2",
			Style {
				sizing_x = sizing_fixed(data.child_2_size.x),
				sizing_y = sizing_fixed(data.child_2_size.y),
				margin = data.child_2_margin,
			},
		)

		end_container(ctx)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}
		parent_size := data.parent_size

		content_start_x := parent_pos.x + data.parent_padding.left
		content_start_y := parent_pos.y + data.parent_padding.top

		// Child 1: Main axis is Y (Top-To-Bottom)
		child_1_pos := base.Vec2 {
			content_start_x + data.child_1_margin.left,
			content_start_y + data.child_1_margin.top,
		}

		// Child 2: positioned below child 1 (child_1 size + child_1 bottom margin + child_2 top margin)
		child_2_pos_y :=
			child_1_pos.y +
			data.child_1_size.y +
			data.child_1_margin.bottom +
			data.child_2_margin.top
		child_2_pos := base.Vec2{content_start_x + data.child_2_margin.left, child_2_pos_y}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = {f32(DEFAULT_TESTING_WINDOW_SIZE.x), f32(DEFAULT_TESTING_WINDOW_SIZE.y)},
			children = []Expected_Element {
				{
					id = "parent",
					pos = parent_pos,
					size = parent_size,
					children = []Expected_Element {
						{id = "child_1", pos = child_1_pos, size = data.child_1_size},
						{id = "child_2", pos = child_2_pos, size = data.child_2_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_margin_does_not_reduce_parent_content_size :: proc(t: ^testing.T) {
	// Test that a parent's margin does NOT reduce the available size for its children
	// Only padding and border should reduce available size

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		parent_size:    base.Vec2,
		parent_padding: Padding,
		parent_margin:  Margin,
		child_size:     base.Vec2,
	}

	test_data := Test_Data {
		parent_size = {300, 200},
		parent_padding = Padding{left = 20, top = 20, right = 20, bottom = 20},
		parent_margin = Margin{left = 50, top = 50, right = 50, bottom = 50},
		child_size = {100, 80},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		begin_container(
			ctx,
			"grandparent",
			Style{sizing_x = sizing_fixed(600), sizing_y = sizing_fixed(500)},
		)

		begin_container(
			ctx,
			"parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				padding = data.parent_padding,
				margin = data.parent_margin,
			},
		)

		container(
			ctx,
			"child",
			Style {
				sizing_x = sizing_fixed(data.child_size.x),
				sizing_y = sizing_fixed(data.child_size.y),
			},
		)

		end_container(ctx) // parent
		end_container(ctx) // grandparent
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Parent is offset by its margin from grandparent's content area
		parent_pos := base.Vec2{data.parent_margin.left, data.parent_margin.top}

		// Child's available space should be: parent_size - parent_padding
		// Parent's margin should NOT reduce this
		content_start_x := parent_pos.x + data.parent_padding.left
		content_start_y := parent_pos.y + data.parent_padding.top

		child_pos := base.Vec2{content_start_x, content_start_y}

		// Verify the available size calculation
		// Available size = parent_size - padding (NOT - margin)
		expected_available_width :=
			data.parent_size.x - data.parent_padding.left - data.parent_padding.right
		expected_available_height :=
			data.parent_size.y - data.parent_padding.top - data.parent_padding.bottom

		// Child should fit within this available space
		testing.expect(
			t,
			data.child_size.x <= expected_available_width,
			"Child width should fit in available width",
		)
		testing.expect(
			t,
			data.child_size.y <= expected_available_height,
			"Child height should fit in available height",
		)

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = {f32(DEFAULT_TESTING_WINDOW_SIZE.x), f32(DEFAULT_TESTING_WINDOW_SIZE.y)},
			children = []Expected_Element {
				{
					id = "grandparent",
					pos = {0, 0},
					size = {600, 500},
					children = []Expected_Element {
						{
							id = "parent",
							pos = parent_pos,
							size = data.parent_size,
							children = []Expected_Element {
								{id = "child", pos = child_pos, size = data.child_size},
							},
						},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_asymmetric_margins :: proc(t: ^testing.T) {
	// Test that asymmetric margins (different values for each side) work correctly

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		parent_size:    base.Vec2,
		child_1_size:   base.Vec2,
		child_2_size:   base.Vec2,
		// Intentionally asymmetric margins
		child_1_margin: Margin,
		child_2_margin: Margin,
	}

	test_data := Test_Data {
		parent_size = {500, 300},
		child_1_size = {100, 100},
		child_2_size = {100, 100},
		child_1_margin = Margin{left = 5, top = 10, right = 30, bottom = 15}, // Asymmetric
		child_2_margin = Margin{left = 40, top = 5, right = 10, bottom = 20}, // Asymmetric
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		begin_container(
			ctx,
			"parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_direction = .Left_To_Right,
			},
		)

		container(
			ctx,
			"child_1",
			Style {
				sizing_x = sizing_fixed(data.child_1_size.x),
				sizing_y = sizing_fixed(data.child_1_size.y),
				margin = data.child_1_margin,
			},
		)

		container(
			ctx,
			"child_2",
			Style {
				sizing_x = sizing_fixed(data.child_2_size.x),
				sizing_y = sizing_fixed(data.child_2_size.y),
				margin = data.child_2_margin,
			},
		)

		end_container(ctx)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		parent_pos := base.Vec2{0, 0}

		// Child 1 position: parent start + left margin
		child_1_pos := base.Vec2 {
			parent_pos.x + data.child_1_margin.left,
			parent_pos.y + data.child_1_margin.top,
		}

		// Child 2 position: child_1 pos + child_1 width + child_1 right margin + child_2 left margin
		child_2_pos_x :=
			child_1_pos.x +
			data.child_1_size.x +
			data.child_1_margin.right +
			data.child_2_margin.left
		child_2_pos := base.Vec2{child_2_pos_x, parent_pos.y + data.child_2_margin.top}

		expected_layout_tree := Expected_Element {
			id       = "root",
			pos      = {0, 0},
			size     = {f32(DEFAULT_TESTING_WINDOW_SIZE.x), f32(DEFAULT_TESTING_WINDOW_SIZE.y)},
			children = []Expected_Element {
				{
					id = "parent",
					pos = parent_pos,
					size = data.parent_size,
					children = []Expected_Element {
						{id = "child_1", pos = child_1_pos, size = data.child_1_size},
						{id = "child_2", pos = child_2_pos, size = data.child_2_size},
					},
				},
			},
		}

		expect_layout(t, ctx, root, expected_layout_tree)
	}

	// --- 4. Run the Test ---
	run_ui_test(t, build_ui_proc, verify_proc, &test_data)
}
