package ui

import "core:fmt"
import "core:mem"
import "core:strings"
import "core:testing"

import base "../base"

expect_intersected_ids :: proc(
	t: ^testing.T,
	elements: [dynamic]^UI_Element,
	expected_ids: []string,
	allocator: mem.Allocator,
	loc := #caller_location,
) {
	// 1. Check Count
	if len(elements) != len(expected_ids) {
		sb := strings.builder_make(allocator)

		strings.write_string(&sb, "[")
		for e, i in elements {
			strings.write_string(&sb, e.id_string)
			if i < len(elements) - 1 {
				strings.write_string(&sb, ", ")
			}
		}
		strings.write_string(&sb, "]")

		msg := fmt.tprintf(
			"Wrong number of intersections.\nExpected: %d %v\nGot:      %d %s",
			len(expected_ids),
			expected_ids,
			len(elements),
			strings.to_string(sb),
		)

		testing.fail_now(t, msg, loc)
	}

	// 2. Check content and order
	for expected, i in expected_ids {
		found_id := elements[i].id_string
		if found_id != expected {
			testing.fail_now(
				t,
				fmt.tprintf(
					"Intersection mismatch at index %d.\nExpected: '%s'\nGot:      '%s'",
					i,
					expected,
					found_id,
				),
				loc,
			)
		}
	}
}

@(test)
test_intersections_deep_hierarchy :: proc(t: ^testing.T) {

	// Scenario: Root -> Container -> Button.
	// We click in the center where all 3 overlap

	Test_Data :: struct {
		pad: Padding,
	}

	build_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		// Layer 1
		container(
			ctx,
			"layer_1",
			Config_Options {
				layout = {
					padding = &data.pad,
					sizing = {
						&Sizing{kind = .Fixed, value = 200},
						&Sizing{kind = .Fixed, value = 200},
					},
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				// Layer 2
				container(
					ctx,
					"layer_2",
					Config_Options {
						layout = {
							padding = &data.pad,
							sizing = {&Sizing{kind = .Grow}, &Sizing{kind = .Grow}},
						},
					},
					data,
					proc(ctx: ^Context, data: ^Test_Data) {
						// Layer 3
						container(
							ctx,
							"layer_3",
							Config_Options {
								layout = {sizing = {&Sizing{kind = .Grow}, &Sizing{kind = .Grow}}},
							},
						)
					},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Root starts at 0,0.
		// Layer 1: 0,0 (200x200)
		// Layer 2: 20,20 (due to padding)
		// Layer 3: 40,40 (due to padding)

		// Intersect in layer 3
		target_pos := base.Vector2i32{50, 50}

		found := make([dynamic]^UI_Element, context.temp_allocator)
		defer free_all(context.temp_allocator)
		find_intersections(ctx, target_pos, &found, context.temp_allocator)

		expect_intersected_ids(
			t,
			found,
			[]string{"root", "layer_1", "layer_2", "layer_3"},
			context.temp_allocator,
		)
	}

	data := Test_Data {
		pad = {20, 20, 20, 20},
	}
	run_ui_test(t, build_proc, verify_proc, &data)
}

@(test)
test_intersections_siblings_distinct :: proc(t: ^testing.T) {
	// Scenario: Two boxes side-by-side
	// Verifies that positiong over one does not return the other

	Test_Data :: struct {
		size: f32,
	}

	build_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		layout_dir := Layout_Direction.Left_To_Right

		container(
			ctx,
			"wrapper",
			Config_Options {
				layout = {
					layout_direction = &layout_dir,
					sizing = {&Sizing{kind = .Fit}, &Sizing{kind = .Fit}},
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				// Box A
				container(
					ctx,
					"box_a",
					Config_Options {
						layout = {
							sizing = {
								&Sizing{kind = .Fixed, value = data.size},
								&Sizing{kind = .Fixed, value = data.size},
							},
						},
					},
				)

				// Box B
				container(
					ctx,
					"box_b",
					Config_Options {
						layout = {
							sizing = {
								&Sizing{kind = .Fixed, value = data.size},
								&Sizing{kind = .Fixed, value = data.size},
							},
						},
					},
				)
			},
		)
	}

	verify_proc :: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^Test_Data) {
		// Box A is at 0,0 to 50,50 relative to wrapper
		// Box B is at 50,0 to 100,50 relative to wrapper

		// 1. Intersect Box A
		{
			target_pos := base.Vector2i32{10, 10}
			found := make([dynamic]^UI_Element, context.temp_allocator)
			defer free_all(context.temp_allocator)
			find_intersections(ctx, target_pos, &found, context.temp_allocator)
			expect_intersected_ids(
				t,
				found,
				[]string{"root", "wrapper", "box_a"},
				context.temp_allocator,
			)
		}

		// 2. Intersect Box B
		{
			target_pos := base.Vector2i32{60, 10}
			found := make([dynamic]^UI_Element, context.temp_allocator)
			defer free_all(context.temp_allocator)
			find_intersections(ctx, target_pos, &found, context.temp_allocator)
			expect_intersected_ids(
				t,
				found,
				[]string{"root", "wrapper", "box_b"},
				context.temp_allocator,
			)
		}
	}

	data := Test_Data {
		size = 50,
	}
	run_ui_test(t, build_proc, verify_proc, &data)
}
