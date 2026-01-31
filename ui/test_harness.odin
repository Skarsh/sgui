package ui

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"
import "core:testing"

import base "../base"

// TODO(Thomas): Update with the allocators that the library uses, e.g. if we settle on
// Pool_Allocator etc.
Test_Environment :: struct {
	ctx:                      Context,
	input:                    base.Input,
	persistent_allocator:     mem.Allocator,
	frame_arena:              virtual.Arena,
	frame_arena_allocator:    mem.Allocator,
	draw_cmd_arena:           virtual.Arena,
	draw_cmd_arena_allocator: mem.Allocator,
}

setup_test_environment :: proc(window_size: [2]i32) -> ^Test_Environment {
	env := new(Test_Environment)

	// Setup arenas and allocators
	env.persistent_allocator = context.allocator

	env.frame_arena = virtual.Arena{}
	frame_arena_alloc_err := virtual.arena_init_static(&env.frame_arena)
	assert(frame_arena_alloc_err == .None)
	env.frame_arena_allocator = virtual.arena_allocator(&env.frame_arena)

	env.draw_cmd_arena = virtual.Arena{}
	draw_cmd_arena_alloc_err := virtual.arena_init_static(&env.draw_cmd_arena)
	assert(draw_cmd_arena_alloc_err == .None)
	env.draw_cmd_arena_allocator = virtual.arena_allocator(&env.draw_cmd_arena)

	init(
		&env.ctx,
		&env.input,
		env.persistent_allocator,
		env.frame_arena_allocator,
		env.draw_cmd_arena_allocator,
		window_size,
		0,
		0,
	)

	return env
}

cleanup_test_environment :: proc(env: ^Test_Environment) {
	deinit(&env.ctx)
	free(env)
}

expect_element_size :: proc(t: ^testing.T, element: ^UI_Element, expected_size: base.Vec2) {
	testing.expect_value(t, element.size.x, expected_size.x)
	testing.expect_value(t, element.size.y, expected_size.y)
}

expect_element_pos :: proc(t: ^testing.T, element: ^UI_Element, expected_pos: base.Vec2) {
	testing.expect_value(t, element.position.x, expected_pos.x)
	testing.expect_value(t, element.position.y, expected_pos.y)
}

Expected_Element :: struct {
	id:       string,
	pos:      base.Vec2,
	size:     base.Vec2,
	children: []Expected_Element,
}

DEFAULT_TESTING_WINDOW_SIZE :: [2]i32{480, 360}

run_ui_test :: proc(
	t: ^testing.T,
	build_ui: proc(ctx: ^Context, data: ^$T),
	verify: proc(t: ^testing.T, ctx: ^Context, root: ^UI_Element, data: ^T),
	data: ^T,
	window_size := DEFAULT_TESTING_WINDOW_SIZE,
) {
	test_env := setup_test_environment(window_size)
	defer cleanup_test_environment(test_env)

	ctx := &test_env.ctx

	set_text_measurement_callbacks(ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	begin(ctx)
	build_ui(ctx, data)
	end(ctx)

	verify(t, ctx, ctx.root_element, data)
}

expect_layout :: proc(
	t: ^testing.T,
	ctx: ^Context,
	parent_element: ^UI_Element,
	expected: Expected_Element,
	epsilon: f32 = EPSILON,
) {
	// Find the actual element in the UI tree corresponding to the expected ID
	element_to_check := find_element_by_id(ctx, expected.id)

	// Fail the test if the element doesn't exist
	if element_to_check == nil {
		testing.fail_now(t, fmt.tprintf("Element with id '%s' not found in layout", expected.id))
	}

	// Compare size and position with a small tolerance
	size_ok := base.approx_equal_vec2(element_to_check.size, expected.size, epsilon)
	pos_ok := base.approx_equal_vec2(element_to_check.position, expected.pos, epsilon)

	if !size_ok {
		testing.fail_now(
			t,
			fmt.tprintf(
				"Element '%s' has wrong size. Expected %v, got %v",
				expected.id,
				expected.size,
				element_to_check.size,
			),
		)
	}

	if !pos_ok {
		testing.fail_now(
			t,
			fmt.tprintf(
				"Element '%s' has wrong position. Expected %v, got %v",
				expected.id,
				expected.pos,
				element_to_check.position,
			),
		)
	}

	if len(element_to_check.children) != len(expected.children) {
		testing.fail_now(
			t,
			fmt.tprintf(
				"Element '%s' has wrong number of children. Expected %d, got %d",
				expected.id,
				len(expected.children),
				len(element_to_check.children),
			),
		)
	}

	for child in expected.children {
		expect_layout(t, ctx, element_to_check, child, epsilon)
	}
}

MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10

mock_measure_text_proc :: proc(text: string, font_id: u16, user_data: rawptr) -> Text_Metrics {
	width: f32 = f32(strings.rune_count(text) * MOCK_CHAR_WIDTH)
	line_height: f32 = MOCK_LINE_HEIGHT

	return Text_Metrics{width = width, line_height = line_height}
}

mock_measure_glyph_proc :: proc(
	codepoint: rune,
	font_id: u16,
	user_data: rawptr,
) -> Glyph_Metrics {
	width: f32 = MOCK_CHAR_WIDTH
	left_bearing: f32 = MOCK_CHAR_WIDTH
	return Glyph_Metrics{width = width, left_bearing = left_bearing}
}
