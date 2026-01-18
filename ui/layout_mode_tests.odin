package ui

import "core:testing"

import base "../base"


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
			container(
				ctx,
				"parent",
				Style {
					sizing_x = sizing_fixed(data.parent_width),
					sizing_y = sizing_fixed(data.parent_height),
					alignment_x = data.alignment_x,
					alignment_y = data.alignment_y,
				},
				data,
				proc(ctx: ^Context, data: ^Test_Data) {
					container(
						ctx,
						"container",
						Style {
							sizing_x = sizing_fixed(data.container_width),
							sizing_y = sizing_fixed(data.container_height),
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
		if begin_container(
			ctx,
			"relative_parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_mode = .Relative,
			},
		) {


			anchor_child :: proc(
				ctx: ^Context,
				id: string,
				child_size_x: f32,
				child_size_y: f32,
				alignment_x: Alignment_X,
				alignment_y: Alignment_Y,
			) {
				container(
					ctx,
					id,
					Style {
						sizing_x = sizing_fixed(child_size_x),
						sizing_y = sizing_fixed(child_size_y),
						alignment_x = alignment_x,
						alignment_y = alignment_y,
					},
				)
			}

			// Top-Left
			anchor_child(ctx, "child_tl", data.child_size.x, data.child_size.y, .Left, .Top)
			// Top-Right
			anchor_child(ctx, "child_tr", data.child_size.x, data.child_size.y, .Right, .Top)
			// Bottom-Right
			anchor_child(ctx, "child_br", data.child_size.x, data.child_size.y, .Right, .Bottom)
			// Bottom-Left
			anchor_child(ctx, "child_bl", data.child_size.x, data.child_size.y, .Left, .Bottom)

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
		if begin_container(
			ctx,
			"relative_parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_mode = .Relative,
			},
		) {

			offset_child :: proc(
				ctx: ^Context,
				id: string,
				child_size_x: f32,
				child_size_y: f32,
				align_x: Alignment_X,
				align_y: Alignment_Y,
				offset: base.Vec2,
			) {
				container(
					ctx,
					id,
					Style {
						sizing_x = sizing_fixed(child_size_x),
						sizing_y = sizing_fixed(child_size_y),
						alignment_x = align_x,
						alignment_y = align_y,
						relative_position = offset,
					},
				)

			}

			// Child 1: Top Left
			offset_child(
				ctx,
				"child_offset_tl",
				data.child_size.x,
				data.child_size.y,
				.Left,
				.Top,
				data.offset_tl,
			)

			// Child 2: Top Right
			offset_child(
				ctx,
				"child_offset_tr",
				data.child_size.x,
				data.child_size.y,
				.Right,
				.Top,
				data.offset_tr,
			)

			// Child 3: Bottom Right
			offset_child(
				ctx,
				"child_offset_br",
				data.child_size.x,
				data.child_size.y,
				.Right,
				.Bottom,
				data.offset_br,
			)

			// Child 4: Bottom Left
			offset_child(
				ctx,
				"child_offset_bl",
				data.child_size.x,
				data.child_size.y,
				.Left,
				.Bottom,
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
		if begin_container(
			ctx,
			"relative_parent",
			Style {
				sizing_x = sizing_fixed(data.parent_size.x),
				sizing_y = sizing_fixed(data.parent_size.y),
				layout_mode = .Relative,
				padding = data.padding,
			},
		) {

			anchor_child :: proc(
				ctx: ^Context,
				id: string,
				child_size_x: f32,
				child_size_y: f32,
				align_x: Alignment_X,
				align_y: Alignment_Y,
			) {
				container(
					ctx,
					id,
					Style {
						sizing_x = sizing_fixed(child_size_x),
						sizing_y = sizing_fixed(child_size_y),
						alignment_x = align_x,
						alignment_y = align_y,
					},
				)
			}

			// Top-Left
			anchor_child(ctx, "child_tl", data.child_size.x, data.child_size.y, .Left, .Top)

			// Top-Right
			anchor_child(ctx, "child_tr", data.child_size.x, data.child_size.y, .Right, .Top)

			// Bottom-Right
			anchor_child(ctx, "child_br", data.child_size.x, data.child_size.y, .Right, .Bottom)

			// Bottom-Left
			anchor_child(ctx, "child_bl", data.child_size.x, data.child_size.y, .Left, .Bottom)

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
// =============================================================================
// MARGIN TESTS
// =============================================================================
