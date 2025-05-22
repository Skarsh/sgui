package ui

import "core:container/small_array"
import "core:log"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:testing"

EPSILON :: 0.001

Axis2 :: enum {
	X,
	Y,
}

Layout_Direction :: enum {
	Left_To_Right,
	Top_To_Bottom,
}

Size_Kind :: enum {
	Fixed,
	Fit,
	Grow,
}

Padding :: struct {
	left:   f32,
	right:  f32,
	top:    f32,
	bottom: f32,
}

UI_Element :: struct {
	parent:           ^UI_Element,
	id_string:        string,
	position:         Vec2,
	min_size:         Vec2,
	size:             Vec2,
	sizing:           [2]Sizing,
	layout_direction: Layout_Direction,
	padding:          Padding,
	child_gap:        f32,
	children:         [dynamic]^UI_Element,
	color:            Color,
}

Sizing :: struct {
	kind:      Size_Kind,
	min_value: f32,
	value:     f32,
}

Element_Config :: struct {
	sizing:           [2]Sizing,
	padding:          Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	color:            Color,
}


calc_child_gap := #force_inline proc(element: UI_Element) -> f32 {
	return f32(len(element.children) - 1) * element.child_gap
}

calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.padding
	padding_sum := axis == .X ? padding.left + padding.right : padding.top + padding.bottom
	size: f32 = 0

	child_gap := calc_child_gap(element^)

	if axis == .X {
		if element.layout_direction == .Left_To_Right {
			for child in element.children {
				size += child.size.x
			}
			size += child_gap
		} else {
			for child in element.children {
				size = max(size, child.size.x)
			}
		}
	} else {
		if element.layout_direction == .Left_To_Right {
			for child in element.children {
				size = max(size, child.size.y)
			}
		} else {
			for child in element.children {
				size += child.size.y
			}
			size += child_gap
		}
	}

	return size + padding_sum
}

open_element :: proc(ctx: ^Context, id: string, element_config: Element_Config) -> bool {
	element, element_ok := make_element(ctx, id, element_config)
	assert(element_ok)

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

// TODO(Thomas): I don't think we should pass in the font sizes like we're doing now,
// this is very permanent and mostly for testing while developing.
// TODO(Thomas): Default value for min_width is just a temporary hack
open_text_element :: proc(
	ctx: ^Context,
	id: string,
	content: string,
	font_width: f32 = CHAR_WIDTH,
	font_height: f32 = CHAR_HEIGHT,
	min_width: f32 = 5 * CHAR_WIDTH,
	min_height: f32 = CHAR_HEIGHT,
) -> bool {
	str_len := len(content)
	content_width: f32 = f32(str_len) * font_width
	content_height: f32 = font_height
	element, element_ok := make_element(
		ctx,
		id,
		Element_Config {
			sizing = {
				{kind = .Grow, min_value = min_width},
				{kind = .Grow, min_value = min_height},
			},
		},
	)
	assert(element_ok)
	element.size.x = f32(content_width)
	element.size.y = f32(content_height)

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent

		if element.sizing.x.kind == .Fit {
			calc_element_fit_size_for_axis(element, .X)
		}

		if element.sizing.y.kind == .Fit {
			calc_element_fit_size_for_axis(element, .Y)
		}
	}
}

update_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent
	if axis == .X && parent.layout_direction == .Left_To_Right {
		parent.size.x += element.size.x
		parent.min_size.x += element.min_size.x
		parent.size.y = max(element.size.y, parent.size.y)
		parent.min_size.y = max(element.min_size.y, parent.min_size.y)

	} else if axis == .Y && parent.layout_direction == .Top_To_Bottom {
		parent.size.x = max(element.size.x, parent.size.x)
		parent.min_size.x = max(element.min_size.x, parent.min_size.x)
		parent.size.y += element.size.y
		parent.min_size.y += element.min_size.y
	}
}

calc_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	if axis == .X {
		element.size.x = calculate_element_size_for_axis(element, axis)
	} else {
		element.size.y = calculate_element_size_for_axis(element, axis)
	}

	if element.parent != nil {
		update_element_fit_size_for_axis(element, axis)
	}

}

calc_remaining_size :: #force_inline proc(element: UI_Element, axis: Axis2) -> f32 {
	padding_sum :=
		axis == .X ? element.padding.left + element.padding.right : element.padding.top + element.padding.bottom

	remaining_size := element.size[axis] - padding_sum
	return remaining_size
}

is_primary_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_primary_axis :=
		(axis == .X && element.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.layout_direction == .Top_To_Bottom)

	return is_primary_axis
}

@(private)
GROW_ITER_MAX :: 32
@(private)
SHRINK_ITER_MAX :: 32

grow_child_elements_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	// NOTE(Thomas): The reason I went for using a Small_Array here instead
	// of just a normal [dynamic]^UI_Element array is because dynamic arrays
	// can have issues with arena allocators if growing, which would be the case
	// if using contex.temp_allocator. So I decided to just go for Small_Array until 
	// I have figured more on how I want to do this. swapping out for Small_Array was very
	// simple, and shouldn't be a problem to go back if we want to use something like a 
	// virtual static arena ourselves to ensure the dynamic array stays in place.
	growables := small_array.Small_Array(1024, ^UI_Element){}

	remaining_size := calc_remaining_size(element^, axis)

	primary_axis := is_primary_axis(element^, axis)

	// Collect growables and update sizes based on layout direction
	if primary_axis {
		child_gap := calc_child_gap(element^)
		for child in element.children {
			size_kind := child.sizing[axis].kind

			if size_kind == .Grow {
				// Add to growables
				small_array.push(&growables, child)
			}

			child_size := child.size[axis]
			remaining_size -= child_size
		}
		remaining_size -= child_gap
	} else {
		// For secondary axis, directly distribute available space
		for child in element.children {
			size_kind := child.sizing[axis].kind
			if size_kind == .Grow {
				child.size[axis] += (remaining_size - child.size[axis])
			}
		}
	}

	grow_iter := 0
	// Process growable children, only if we have collected any
	if len(small_array.slice(&growables)) > 0 {
		for remaining_size > EPSILON {
			assert(grow_iter < GROW_ITER_MAX)
			grow_iter += 1
			// Initialize with the first child's size
			smallest := small_array.get(growables, 0).size[axis]
			second_smallest := math.INF_F32
			size_to_add := remaining_size

			// Find smallest and second-smallest sizes
			for child in small_array.slice(&growables) {
				child_size := child.size[axis]

				if child_size < smallest {
					second_smallest = smallest
					smallest = child_size
				} else if child_size > smallest {
					second_smallest = min(second_smallest, child_size)
					size_to_add = second_smallest - smallest
				}
			}

			// Calculate how much to add
			size_to_add = min(
				size_to_add,
				remaining_size / f32(len(small_array.slice(&growables))),
			)

			// Add size to the smallest elements
			for child in small_array.slice(&growables) {
				child_size := child.size[axis]
				if approx_equal(child_size, smallest, EPSILON) {
					child.size[axis] += size_to_add
					remaining_size -= size_to_add
				}
			}
		}
	}

	for child in element.children {
		grow_child_elements_for_axis(child, axis)
	}
}

shrink_child_elements_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	shrinkables := small_array.Small_Array(1024, ^UI_Element){}

	remaining_size := calc_remaining_size(element^, axis)

	primary_axis := is_primary_axis(element^, axis)

	// Collect shrinkables
	if primary_axis {
		child_gap := calc_child_gap(element^)
		for child in element.children {
			size_kind := child.sizing[axis].kind
			if size_kind == .Grow {
				// Find the shrinkable elements and
				// add them to the shrinkables dynamic array
				// Shrinkable elements are elements that are not at their min size yet
				// along the given axis
				child_size := child.size[axis]
				child_min_size := child.min_size[axis]
				if child_size > child_min_size {
					small_array.push(&shrinkables, child)
				}
			}

			child_size := child.size[axis]
			remaining_size -= child_size
		}
		remaining_size -= child_gap
	}

	shrink_iter := 0
	for remaining_size < -EPSILON && len(small_array.slice(&shrinkables)) > 0 {
		assert(shrink_iter < SHRINK_ITER_MAX)
		shrink_iter += 1
		largest := small_array.get(shrinkables, 0).size[axis]
		second_largest: f32 = 0
		size_to_add := remaining_size

		for child in small_array.slice(&shrinkables) {
			child_size := child.size[axis]
			if child_size > largest {
				second_largest = largest
				largest = child_size
			} else if child_size < largest {
				second_largest = max(second_largest, child_size)
				size_to_add = second_largest - largest
			}
		}

		size_to_add = max(size_to_add, remaining_size / f32(len(small_array.slice(&shrinkables))))

		for child, idx in small_array.slice(&shrinkables) {
			prev_size := child.size[axis]
			child_size := child.size[axis]
			child_min_size := child.min_size[axis]
			if approx_equal(child_size, largest, EPSILON) {
				child_size += size_to_add
				child.size[axis] = child_size

				if child_size <= child_min_size {
					child_size = child_min_size
					child.size[axis] = child_size
					small_array.unordered_remove(&shrinkables, idx)
				}
				remaining_size -= (child_size - prev_size)
			}
		}
	}

	for child in element.children {
		shrink_child_elements_for_axis(child, axis)
	}

}

make_element :: proc(
	ctx: ^Context,
	id: string,
	element_config: Element_Config,
) -> (
	^UI_Element,
	bool,
) {

	key := ui_key_hash(id)

	element, found := ctx.element_cache[key]

	if !found {
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.persistent_allocator)
		assert(err == .None)
		if err != .None {
			log.error("failed to allocate UI_Element")
			return nil, false
		}
		element.parent = ctx.current_parent
		element.id_string = id
		element.children = make([dynamic]^UI_Element, ctx.persistent_allocator)
		if element.parent != nil {
			append(&element.parent.children, element)
		}

		ctx.element_cache[key] = element
	}

	// We need to set this fields every frame
	element.sizing = element_config.sizing
	element.layout_direction = element_config.layout_direction
	element.padding = element_config.padding
	element.child_gap = element_config.child_gap
	element.position.x = 0
	element.position.y = 0
	element.color = element_config.color

	if element.sizing.x.kind == .Fixed {
		element.min_size.x = element.sizing.x.min_value
		element.size.x = element.sizing.x.value
	}

	if element.sizing.y.kind == .Fixed {
		element.min_size.y = element.sizing.y.min_value
		element.size.y = element.sizing.y.value
	}

	return element, true
}

calculate_positions :: proc(parent: ^UI_Element) {
	if parent == nil {
		return
	}

	// First, calculate positions of all children relative to the parent's content area
	content_start_x := parent.position.x + parent.padding.left
	content_start_y := parent.position.y + parent.padding.top

	current_x := content_start_x
	current_y := content_start_y

	for i in 0 ..< len(parent.children) {
		child := parent.children[i]

		// Position this child
		child.position.x = current_x
		child.position.y = current_y

		// Update position for next child based on layout direction
		if parent.layout_direction == .Left_To_Right {
			if len(parent.children) >= 1 && i < len(parent.children) - 1 {
				current_x += child.size.x + parent.child_gap
			} else {
				current_x += child.size.x
			}
		} else { 	// Top_To_Bottom
			current_y += child.size.y + parent.child_gap
		}
	}

	// Then recursively calculate positions for all children's children
	for child in parent.children {
		calculate_positions(child)
	}
}

// Helper to verify element size
compare_element_size :: proc(
	element: UI_Element,
	expected_size: Vec2,
	epsilon: f32 = EPSILON,
) -> bool {
	return approx_equal_vec2(element.size, expected_size, epsilon)
}

// Helper to verify element position
compare_element_position :: proc(
	element: UI_Element,
	expected_pos: Vec2,
	epsilon: f32 = EPSILON,
) -> bool {
	return approx_equal_vec2(element.position, expected_pos, epsilon)
}

// Helper to find an element in element hierarchy by id string
find_element_by_id :: proc(root: ^UI_Element, id: string) -> ^UI_Element {
	if root == nil {
		return nil
	}

	if root.id_string == id {
		return root
	}

	for child in root.children {
		if result := find_element_by_id(child, id); result != nil {
			return result
		}
	}

	return nil
}

/////////////////////////////// Testing ///////////////////////////////

Test_Environment :: struct {
	ctx:             Context,
	arena:           virtual.Arena,
	arena_buffer:    []u8,
	arena_allocator: mem.Allocator,
}

// NOTE(Thomas): The reason we're returning a pointer to the 
// Test_Environment here is to make sure that the allocators live
// long enough.
setup_test_environment :: proc() -> ^Test_Environment {
	env := new(Test_Environment)

	// Setup arena and allocator
	env.arena_buffer = make([]u8, 100 * 1024)
	arena_alloc_err := virtual.arena_init_buffer(&env.arena, env.arena_buffer)
	assert(arena_alloc_err == .None)
	env.arena_allocator = virtual.arena_allocator(&env.arena)

	init(&env.ctx, env.arena_allocator, env.arena_allocator)

	return env
}

cleanup_test_environment :: proc(env: ^Test_Environment) {
	deinit(&env.ctx)
	free_all(env.arena_allocator)
	delete(env.arena_buffer)
	free(env)
}

expect_element_size :: proc(t: ^testing.T, element: ^UI_Element, expected_size: Vec2) {
	testing.expect_value(t, element.size.x, expected_size.x)
	testing.expect_value(t, element.size.y, expected_size.y)
}

expect_element_pos :: proc(t: ^testing.T, element: ^UI_Element, expected_pos: Vec2) {
	testing.expect_value(t, element.position.x, expected_pos.x)
	testing.expect_value(t, element.position.y, expected_pos.y)
}

@(test)
test_fit_sizing_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10
	container_1_size := Vec2{100, 100}
	container_2_size := Vec2{50, 150}
	container_3_size := Vec2{150, 150}
	largest_container_x: f32 = 150
	largest_container_y: f32 = 150

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {{kind = .Fit}, {kind = .Fit}},
			layout_direction = .Left_To_Right,
			padding = panel_padding,
			child_gap = 10,
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_1_size.x},
					{kind = .Fixed, value = container_1_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_2_size.x},
					{kind = .Fixed, value = container_2_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_3_size.x},
					{kind = .Fixed, value = container_3_size.y},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions(ctx.root_element)

	panel_element := find_element_by_id(ctx.root_element, "panel")
	testing.expect(t, panel_element != nil)


	expected_panel_size := testing.expect_value(
		t, // assert panel size
		panel_element.size.x,
		panel_padding.left +
		container_1_size.x +
		panel_child_gap +
		container_2_size.x +
		panel_child_gap +
		container_3_size.x +
		panel_padding.right,
	)
	testing.expect_value(
		t,
		panel_element.size.y,
		panel_padding.top + largest_container_y + panel_padding.bottom,
	)

	// assert panel positions
	testing.expect_value(t, panel_element.position.x, 0)
	testing.expect_value(t, panel_element.position.y, 0)

	// assert container_1 size
	container_1_element := panel_element.children[0]
	testing.expect_value(t, container_1_element.size.x, container_1_size.x)
	testing.expect_value(t, container_1_element.size.y, container_1_size.y)

	// asert container_1 position
	testing.expect_value(t, container_1_element.position.x, panel_padding.left)
	testing.expect_value(t, container_1_element.position.y, panel_padding.top)

	// assert container_2 size
	container_2_element := panel_element.children[1]
	testing.expect_value(t, container_2_element.size.x, container_2_size.x)
	testing.expect_value(t, container_2_element.size.y, container_2_size.y)

	// assert container_2 position
	testing.expect_value(
		t,
		container_2_element.position.x,
		container_1_element.position.x + container_1_element.size.x + panel_child_gap,
	)
	testing.expect_value(t, container_2_element.position.y, panel_padding.top)

	// assert container_3 size
	container_3_element := panel_element.children[2]
	testing.expect_value(t, container_3_element.size.x, container_3_size.x)
	testing.expect_value(t, container_3_element.size.y, container_3_size.y)

	// assert container_3 position
	testing.expect_value(
		t,
		container_3_element.position.x,
		container_2_element.position.x + container_2_element.size.x + panel_child_gap,
	)
	testing.expect_value(t, container_3_element.position.y, panel_padding.top)
}

@(test)
test_fit_sizing_ttb :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10
	container_1_size := Vec2{100, 100}
	container_2_size := Vec2{50, 150}
	container_3_size := Vec2{150, 150}
	largest_container_x: f32 = 150
	largest_container_y: f32 = 150

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {{kind = .Fit}, {kind = .Fit}},
			layout_direction = .Top_To_Bottom,
			padding = panel_padding,
			child_gap = 10,
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_1_size.x},
					{kind = .Fixed, value = container_1_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_2_size.x},
					{kind = .Fixed, value = container_2_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_3_size.x},
					{kind = .Fixed, value = container_3_size.y},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions(ctx.root_element)

	panel_element := find_element_by_id(ctx.root_element, "panel")
	testing.expect(t, panel_element != nil)

	// assert panel size
	testing.expect_value(
		t,
		panel_element.size.y,
		panel_padding.top +
		container_1_size.y +
		panel_child_gap +
		container_2_size.y +
		panel_child_gap +
		container_3_size.y +
		panel_padding.bottom,
	)
	testing.expect_value(
		t,
		panel_element.size.x,
		panel_padding.left + largest_container_x + panel_padding.right,
	)

	// assert panel positions
	testing.expect_value(t, panel_element.position.x, 0)
	testing.expect_value(t, panel_element.position.y, 0)

	// assert container_1 size
	container_1_element := panel_element.children[0]
	testing.expect_value(t, container_1_element.size.x, container_1_size.x)
	testing.expect_value(t, container_1_element.size.y, container_1_size.y)

	// asert container_1 position
	testing.expect_value(t, container_1_element.position.x, panel_padding.left)
	testing.expect_value(t, container_1_element.position.y, panel_padding.right)

	// assert container_2 size
	container_2_element := panel_element.children[1]
	testing.expect_value(t, container_2_element.size.x, container_2_size.x)
	testing.expect_value(t, container_2_element.size.y, container_2_size.y)

	// assert container_2 position
	testing.expect_value(t, container_2_element.position.x, panel_padding.right)
	testing.expect_value(
		t,
		container_2_element.position.y,
		panel_padding.top + container_1_element.size.y + panel_child_gap,
	)

	// assert container_3 size
	container_3_element := panel_element.children[2]
	testing.expect_value(t, container_3_element.size.x, container_3_size.x)
	testing.expect_value(t, container_3_element.size.y, container_3_size.y)

	// assert container_3 position
	testing.expect_value(t, container_3_element.position.x, panel_padding.left)
	testing.expect_value(
		t,
		container_3_element.position.y,
		container_2_element.position.y + container_2_element.size.y + panel_child_gap,
	)
}

@(test)
test_grow_sizing_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10
	panel_size := Vec2{600, 400}
	container_1_size := Vec2{100, 100}
	container_2_size := Vec2{600 - 150 - 100, 400}
	container_3_size := Vec2{150, 150}

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Left_To_Right,
			padding = panel_padding,
			child_gap = 10,
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_1_size.x},
					{kind = .Fixed, value = container_1_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config{sizing = {{kind = .Grow}, {kind = .Grow}}},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_3_size.x},
					{kind = .Fixed, value = container_3_size.y},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions(ctx.root_element)

	panel_element := find_element_by_id(ctx.root_element, "panel")

	// assert panel size
	testing.expect_value(t, panel_element.size.x, panel_size.x)
	testing.expect_value(t, panel_element.size.y, panel_size.y)

	// assert panel positions
	testing.expect_value(t, panel_element.position.x, 0)
	testing.expect_value(t, panel_element.position.y, 0)

	// assert container_1 size
	container_1_element := panel_element.children[0]
	testing.expect_value(t, container_1_element.size.x, container_1_size.x)
	testing.expect_value(t, container_1_element.size.y, container_1_size.y)

	// asert container_1 position
	testing.expect_value(t, container_1_element.position.x, panel_padding.left)
	testing.expect_value(t, container_1_element.position.y, panel_padding.top)

	// assert container_2 size
	container_2_element := panel_element.children[1]
	testing.expect_value(
		t,
		container_2_element.size.x,
		panel_size.x -
		panel_padding.left -
		panel_padding.right -
		(2 * panel_child_gap) -
		container_1_size.x -
		container_3_size.x,
	)
	testing.expect_value(
		t,
		container_2_element.size.y,
		panel_size.y - panel_padding.top - panel_padding.bottom,
	)

	// assert container_2 position
	testing.expect_value(
		t,
		container_2_element.position.x,
		container_1_element.position.x + container_1_element.size.x + panel_child_gap,
	)
	testing.expect_value(t, container_2_element.position.y, panel_padding.top)

	// assert container_3 size
	container_3_element := panel_element.children[2]
	testing.expect_value(t, container_3_element.size.x, container_3_size.x)
	testing.expect_value(t, container_3_element.size.y, container_3_size.y)

	// assert container_3 position
	testing.expect_value(
		t,
		container_3_element.position.x,
		container_2_element.position.x + container_2_element.size.x + panel_child_gap,
	)
	testing.expect_value(t, container_3_element.position.y, panel_padding.top)
}

@(test)
test_grow_sizing_ttb :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10
	panel_size := Vec2{600, 400}
	container_1_size := Vec2{100, 100}
	container_2_size := Vec2{600, 400 - 150 - 100}
	container_3_size := Vec2{150, 150}

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Top_To_Bottom,
			padding = panel_padding,
			child_gap = 10,
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_1_size.x},
					{kind = .Fixed, value = container_1_size.y},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config{sizing = {{kind = .Grow}, {kind = .Grow}}},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				sizing = {
					{kind = .Fixed, value = container_3_size.x},
					{kind = .Fixed, value = container_3_size.y},
				},
			},
		)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)
	calculate_positions(ctx.root_element)
	panel_element := find_element_by_id(ctx.root_element, "panel")

	// assert panel size
	testing.expect_value(t, panel_element.size.x, panel_size.x)
	testing.expect_value(t, panel_element.size.y, panel_size.y)

	// assert panel positions
	testing.expect_value(t, panel_element.position.x, 0)
	testing.expect_value(t, panel_element.position.y, 0)

	// assert container_1 size
	container_1_element := panel_element.children[0]
	testing.expect_value(t, container_1_element.size.x, container_1_size.x)
	testing.expect_value(t, container_1_element.size.y, container_1_size.y)

	// assert container_1 position
	testing.expect_value(t, container_1_element.position.x, panel_padding.left)
	testing.expect_value(t, container_1_element.position.y, panel_padding.top)

	// assert container_2 size
	container_2_element := panel_element.children[1]
	testing.expect_value(
		t,
		container_2_element.size.x,
		panel_size.x - panel_padding.left - panel_padding.right,
	)
	testing.expect_value(
		t,
		container_2_element.size.y,
		panel_size.y -
		panel_padding.top -
		panel_padding.bottom -
		(2 * panel_child_gap) -
		container_1_size.y -
		container_3_size.y,
	)

	// assert container_2 position
	testing.expect_value(t, container_2_element.position.x, panel_padding.left)
	testing.expect_value(
		t,
		container_2_element.position.y,
		container_1_element.position.y + container_1_element.size.y + panel_child_gap,
	)

	// assert container_3 size
	container_3_element := panel_element.children[2]
	testing.expect_value(t, container_3_element.size.x, container_3_size.x)
	testing.expect_value(t, container_3_element.size.y, container_3_size.y)

	// assert container_3 position
	testing.expect_value(t, container_3_element.position.x, panel_padding.left)
	testing.expect_value(
		t,
		container_3_element.position.y,
		container_2_element.position.y + container_2_element.size.y + panel_child_gap,
	)
}

@(test)
test_single_text_element_grow_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_size := Vec2{100, 100}
	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Top_To_Bottom,
			padding = panel_padding,
			child_gap = panel_child_gap,
		},
	)
	{
		open_text_element(&ctx, "text", "AAAAA", 10, 10)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	panel_element := find_element_by_id(ctx.root_element, "panel")
	text_element := panel_element.children[0]

	testing.expect_value(
		t,
		text_element.size.x,
		panel_size.x - panel_padding.left - panel_padding.right,
	)
}

@(test)
test_multiple_text_element_grow_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_size := Vec2{100, 100}
	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Left_To_Right,
			padding = panel_padding,
			child_gap = panel_child_gap,
		},
	)
	{
		open_text_element(&ctx, "text", "AA", 10, 10)
		close_element(&ctx)
		open_text_element(&ctx, "text 2", "AA", 10, 10)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	panel_element := ctx.root_element.children[0]
	text_element_1 := panel_element.children[0]
	text_element_2 := panel_element.children[1]

	expected_text_element_width :=
		(panel_size.x - panel_padding.left - panel_padding.right - panel_child_gap) / 2
	expected_text_element_height := panel_size.y - panel_padding.top - panel_padding.bottom
	expected_size := Vec2{expected_text_element_width, expected_text_element_height}

	testing.expect(t, compare_element_size(text_element_1^, expected_size))
}

@(test)
test_single_text_element_shrink_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_size := Vec2{100, 100}
	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Left_To_Right,
			padding = panel_padding,
			child_gap = panel_child_gap,
		},
	)
	{
		open_text_element(&ctx, "text", "AAAAA_AAAAA", 10, 10)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	panel_element := ctx.root_element.children[0]
	text_element := panel_element.children[0]

	testing.expect_value(
		t,
		text_element.size.x,
		panel_size.x - panel_padding.left - panel_padding.right,
	)
}

@(test)
test_multiple_text_element_shrink_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_size := Vec2{100, 100}
	panel_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}
	panel_child_gap: f32 = 10

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Left_To_Right,
			padding = panel_padding,
			child_gap = panel_child_gap,
		},
	)
	{
		open_text_element(&ctx, "text", "AAAAA_AAAAA", 10, 10)
		close_element(&ctx)
		open_text_element(&ctx, "text 2", "AAAAA_AAAAA", 10, 10)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	panel_element := find_element_by_id(ctx.root_element, "panel")
	text_element_1 := panel_element.children[0]
	text_element_2 := panel_element.children[1]

	expected_text_element_width :=
		(panel_size.x - panel_padding.left - panel_padding.right - panel_child_gap) / 2

	expected_text_element_height := panel_element.size.y - panel_padding.top - panel_padding.bottom

	expected_size := Vec2{expected_text_element_width, expected_text_element_height}

	testing.expect(t, compare_element_size(text_element_1^, expected_size))
	testing.expect(t, compare_element_size(text_element_2^, expected_size))
}

@(test)
test_shrink_stops_at_min_size_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_size := Vec2{200, 100}

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			sizing = {
				{kind = .Fixed, value = panel_size.x},
				{kind = .Fixed, value = panel_size.y},
			},
			layout_direction = .Left_To_Right,
		},
	)
	{
		open_text_element(&ctx, "text_1", "0123456789", 10, 10, min_width = 30)
		close_element(&ctx)
		open_text_element(&ctx, "text_2", "0123456789", 10, 10, min_width = 30)
		close_element(&ctx)
		open_text_element(&ctx, "text_3", "0123456789", 10, 10, min_width = 90)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	text_element_1 := find_element_by_id(ctx.root_element, "text_1")
	text_element_2 := find_element_by_id(ctx.root_element, "text_2")
	text_element_3 := find_element_by_id(ctx.root_element, "text_3")

	testing.expect_value(t, text_element_3.size.x, 90)
}
