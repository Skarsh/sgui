package ui

import "core:testing"

import base "../base"


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
		main_padding          = padding_all(10),
		main_child_gap        = 5,
		row_layout_direction  = .Left_To_Right,
		row_padding           = padding_all(5),
		row_child_gap         = 2,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		main_sizing := [2]Sizing{sizing_fit(), sizing_fit()}
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
		sizing := [2]Sizing{sizing_fit(), sizing_fit()}
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
								&Sizing {
									kind = .Grow,
									min_value = data.text_min_width,
									max_value = data.text_max_width,
								},
								&Sizing{kind = .Grow},
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
		sizing := [2]Sizing{sizing_fit(), sizing_fit()}
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
		container_id      = "container",
		container_padding = padding_all(10),
		text_id           = "text",
		text              = "Button 1",
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		sizing := [2]Sizing{sizing_fixed(60), sizing_fit()}
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

		sizing := [2]Sizing{sizing_fit(), sizing_fit()}
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
								&Sizing{kind = .Grow, min_value = data.text_min_width},
								&Sizing{kind = .Grow, min_value = data.text_min_height},
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
		sizing := [2]Sizing{sizing_fit(), sizing_fit()}
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
