package ui

import "core:fmt"
import "core:testing"

import base "../base"

// Tests in this file focus on the UI Context lifecycle, some of which are:
// - Frame-to-frame persistence (Caching)

@(test)
test_fixed_sizing_updates_cached_element :: proc(t: ^testing.T) {
	// 1. Manual Setup
	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	// 2. Test Data
	Test_Data :: struct {
		element_height: f32,
	}

	data := Test_Data {
		element_height = 100,
	}

	// 3. Build logic

	build_ui :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"resizable_box",
			Style{sizing_x = sizing_fixed(100), sizing_y = sizing_fixed(data.element_height)},
		)
	}

	// --- Frame 1: Initial Render ---
	begin(ctx)
	build_ui(ctx, &data)
	end(ctx)

	// Verify Frame 1
	elem_f1 := find_element_by_id(ctx, "resizable_box")
	if elem_f1 == nil {
		testing.fail_now(t, "Frame 1: Element 'resizable_box' not found")
	}
	testing.expect_value(t, elem_f1.size.y, 100)

	// --- Frame 2: Update Configuration ---
	// We change the input data. This simulates the user dragging a scrollbar
	// or changing a slider value in the application loop.
	data.element_height = 50

	begin(ctx)
	build_ui(ctx, &data)
	end(ctx)

	// Verify Frame 2
	elem_f2 := find_element_by_id(ctx, "resizable_box")
	if elem_f2 == nil {
		testing.fail_now(t, "Frame 2: Element 'resizable_box' not found")
	}

	if !base.approx_equal(elem_f2.size.y, 50, EPSILON) {
		testing.fail_now(
			t,
			fmt.tprintf(
				"Cache invalidation failed. Expected size 50, got %v.\n" +
				"The cached element retained its old Fixed size despite new config.",
				elem_f2.size.y,
			),
		)
	}

}
