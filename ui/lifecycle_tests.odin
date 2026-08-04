package ui

import "core:fmt"
import "core:testing"

import base "../base"

// Tests in this file focus on the UI Context lifecycle, some of which are:
// * Frame-to-frame persistence (Caching)

@(test)
test_get_element_by_key_for_missing_key :: proc(t: ^testing.T) {
	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	_, ok := get_element_by_key(ctx, ui_key_hash("never_built"))
	testing.expect(t, !ok)
}

@(test)
test_fixed_sizing_updates_cached_element :: proc(t: ^testing.T) {
	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	Test_Data :: struct {
		element_height: f32,
	}

	data := Test_Data {
		element_height = 100,
	}

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
	elem_f1, elem_f1_ok := get_element_by_string_id(ctx, "resizable_box")
	if !elem_f1_ok {
		testing.fail_now(t, "Frame 1: Element 'resizable_box' not found")
	}
	testing.expect_value(t, elem_f1.size.y, 100)

	// --- Frame 2: Update Configuration ---
	data.element_height = 50

	begin(ctx)
	build_ui(ctx, &data)
	end(ctx)

	// Verify Frame 2
	elem_f2, elem_f2_ok := get_element_by_string_id(ctx, "resizable_box")
	if !elem_f2_ok {
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

@(private)
check_capability_flags :: proc(
	t: ^testing.T,
	ctx: ^Context,
	id: string,
	expected: Capability_Flags,
	loc := #caller_location,
) {
	element, ok := get_element_by_string_id(ctx, id)
	testing.expectf(t, ok, "failed to find %q", id, loc = loc)
	testing.expectf(
		t,
		element.config.capability_flags == expected,
		"%q: expected capabilites %v, got %v",
		id,
		expected,
		element.config.capability_flags,
		loc = loc,
	)
}

@(test)
test_capabilities :: proc(t: ^testing.T) {

	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	build_ui :: proc(ctx: ^Context) {
		push_style(ctx, Style{capability_flags = Capability_Flags{.Background}})
		defer pop_style(ctx)

		// Element 1 does not set any capability flags itself, should "inherit" the
		// one from the style stack.
		container(ctx, "element_1")

		// Element 2 does not have any capability flags, should override what comes
		// from the style stack
		container(ctx, "element_2", Style{capability_flags = Capability_Flags{}})

		// Element 3 is a superset of the capabilities on the style stack
		container(
			ctx,
			"element_3",
			Style{capability_flags = Capability_Flags{.Background, .Clickable}},
		)
	}

	begin(ctx)
	build_ui(ctx)
	end(ctx)

	check_capability_flags(t, ctx, "element_1", {.Background})
	check_capability_flags(t, ctx, "element_2", Capability_Flags{})
	check_capability_flags(t, ctx, "element_3", {.Background, .Clickable})

}
