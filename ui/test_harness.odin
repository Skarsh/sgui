package ui

import "core:mem"
import "core:mem/virtual"
import "core:testing"

import base "../base"
import textpkg "../text"

// TODO(Thomas): Update with the allocators that the library uses, e.g. if we settle on
// Pool_Allocator etc.
Test_Environment :: struct {
	ctx:                      Context,
	input:                    base.Input,
	text_measurement:         textpkg.Text_Measurement,
	persistent_allocator:     mem.Allocator,
	frame_arena:              virtual.Arena,
	frame_arena_allocator:    mem.Allocator,
	draw_cmd_arena:           virtual.Arena,
	draw_cmd_arena_allocator: mem.Allocator,
}

setup_test_environment :: proc(window_size: [2]i32) -> ^Test_Environment {
	env := new(Test_Environment)

	// Text measurement
	env.text_measurement = textpkg.Text_Measurement {
		measure_text_proc      = textpkg.mock_measure_text_proc,
		measure_codepoint_proc = textpkg.mock_measure_codepoint_proc,
	}

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
		&env.text_measurement,
		env.persistent_allocator,
		env.frame_arena_allocator,
		env.draw_cmd_arena_allocator,
		window_size,
		{{"", 0, nil}},
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

Element_Spec :: struct {
	style:    Style,
	text:     string,
	children: []Element_Spec,
	name:     string,
}

Expected_Element :: struct {
	pos:      base.Vec2,
	size:     base.Vec2,
	children: []Expected_Element,
	name:     string,
}

DEFAULT_TESTING_WINDOW_SIZE :: [2]i32{480, 360}

MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10

run_ui_test :: proc(
	t: ^testing.T,
	build_ui: proc(ctx: ^Context, data: ^$T),
	verify: proc(t: ^testing.T, ctx: ^Context, root: UI_Element, data: ^T),
	data: ^T,
	window_size := DEFAULT_TESTING_WINDOW_SIZE,
) {
	test_env := setup_test_environment(window_size)
	defer cleanup_test_environment(test_env)

	ctx := &test_env.ctx

	begin(ctx)
	build_ui(ctx, data)
	end(ctx)

	verify(t, ctx, ctx.root_element^, data)
}

check_layout :: proc(
	t: ^testing.T,
	spec: Element_Spec,
	expected: Expected_Element,
	window_size := DEFAULT_TESTING_WINDOW_SIZE,
	loc := #caller_location,
) {
	env := setup_test_environment(window_size)
	defer cleanup_test_environment(env)

	begin(&env.ctx)
	build_spec(&env.ctx, spec)
	end(&env.ctx)

	root := env.ctx.root_element
	if testing.expectf(
		t,
		len(root.children) == 1,
		"expected a single top-level element under root, got %d",
		len(root.children),
		loc = loc,
	) {
		expect_layout(t, root.children[0], expected, loc = loc)
	}
}

build_spec :: proc(ctx: ^Context, spec: Element_Spec, loc := #caller_location) {
	if spec.text != "" {
		text(ctx, spec.text, spec.style, name = spec.name, loc = loc)
	} else {
		begin_container(ctx, spec.style, name = spec.name, loc = loc)
		for child, i in spec.children {
			push_id(ctx, i)
			build_spec(ctx, child)
			pop_id(ctx)
		}
		end_container(ctx)
	}
}

expect_layout :: proc(
	t: ^testing.T,
	element: ^UI_Element,
	expected: Expected_Element,
	epsilon: f32 = EPSILON,
	loc := #caller_location,
) {
	// Testing position
	testing.expectf(
		t,
		base.approx_equal_vec2(element.position, expected.pos, epsilon),
		"element '%s': expected position %v, got %v",
		expected.name,
		expected.pos,
		element.position,
		loc = loc,
	)

	// Testing size
	testing.expectf(
		t,
		base.approx_equal_vec2(element.size, expected.size, epsilon),
		"element '%s': expected size %v, got %v",
		expected.name,
		expected.size,
		element.size,
		loc = loc,
	)

	// Testing children count
	if testing.expectf(
		t,
		len(element.children) == len(expected.children),
		"element '%s': expected %d children, got %d",
		expected.name,
		len(expected.children),
		len(element.children),
		loc = loc,
	) {
		// Testing children layout
		for child, i in expected.children {
			expect_layout(t, element.children[i], child, epsilon, loc)
		}
	}
}
