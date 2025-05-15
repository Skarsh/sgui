package ui

import "core:log"
import "core:math"
import "core:mem"
import "core:mem/virtual"
import "core:testing"

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

calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.padding
	padding_sum := axis == .X ? padding.left + padding.right : padding.top + padding.bottom
	size: f32 = 0

	child_gap := f32(len(element.children) - 1) * element.child_gap

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

open_text_element :: proc(ctx: ^Context, id: string, content: string) -> bool {
	str_len := len(content)
	content_width := str_len * CHAR_WIDTH
	content_height := CHAR_HEIGHT
	element, element_ok := make_element(
		ctx,
		id,
		Element_Config {
			sizing = {
				{kind = .Grow, min_value = CHAR_WIDTH},
				{kind = .Grow, min_value = CHAR_HEIGHT},
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
		parent.min_size.x = max(element.min_size.x, parent.min_size.x)
		parent.size.x = max(element.size.x, parent.size.x)
		parent.min_size.y += element.min_size.y
		parent.size.y += element.size.y
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

@(private)
GROW_ITER_MAX :: 1024
@(private)
SHRINK_ITER_MAX :: 1024


grow_child_elements_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	growables := make([dynamic]^UI_Element, context.temp_allocator)
	shrinkables := make([dynamic]^UI_Element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	padding_sum :=
		axis == .X ? element.padding.left + element.padding.right : element.padding.top + element.padding.bottom

	remaining_size := element.size[axis] - padding_sum

	is_primary_axis :=
		(axis == .X && element.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.layout_direction == .Top_To_Bottom)

	// Collect growables and update sizes based on layout direction
	if is_primary_axis {
		child_gap := f32(len(element.children) - 1) * element.child_gap
		for child in element.children {
			size_kind := child.sizing[axis].kind

			if size_kind == .Grow {
				// Add to growables
				append(&growables, child)

				// Find the shrinkable elements and
				// add them to the shrinkables dynamic array
				// Shrinkable elements are elements that are not at their min size yet
				// along the given axis
				child_size := child.size[axis]
				child_min_size := child.min_size[axis]
				if child_size > child_min_size {
					append(&shrinkables, child)
				}
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
				if axis == .X {
					child.size.x += (remaining_size - child.size.x)
				} else {
					child.size.y += (remaining_size - child.size.y)
				}
			}
		}
	}

	grow_iter := 0
	// Process growable children, only if we have collected any
	if len(growables) > 0 {
		for remaining_size > 0 {
			assert(grow_iter < GROW_ITER_MAX)
			grow_iter += 1
			// Initialize with the first child's size
			smallest := growables[0].size[axis]
			second_smallest := math.INF_F32
			size_to_add := remaining_size

			// Find smallest and second-smallest sizes
			for child in growables {
				child_size := child.size[axis]

				if child_size < smallest {
					second_smallest = smallest
					smallest = child_size
				} else if child_size > smallest {
					second_smallest = min(second_smallest, child_size)
					size_to_add = second_smallest
				}
			}

			// Calculate how much to add
			size_to_add = min(size_to_add, remaining_size / f32(len(growables)))

			// Add size to the smallest elements
			for child in growables {
				child_size := child.size[axis]
				if child_size == smallest {
					if axis == .X {
						child.size.x += size_to_add
					} else {
						child.size.y += size_to_add
					}
					remaining_size -= size_to_add
				}
			}
		}
	}

	shrink_iter := 0
	for remaining_size < 0 && len(shrinkables) > 0 {
		assert(shrink_iter < SHRINK_ITER_MAX)
		shrink_iter += 1
		largest := shrinkables[0].size[axis]
		second_largest: f32 = 0
		size_to_add := remaining_size

		for child in shrinkables {
			child_size := child.size[axis]
			if child_size > largest {
				second_largest = largest
				largest = child_size
			} else if child_size < largest {
				second_largest = max(second_largest, child_size)
				size_to_add = second_largest - largest
			}
		}

		size_to_add = max(size_to_add, remaining_size / f32(len(shrinkables)))

		for child, idx in shrinkables {
			prev_size := child.size[axis]
			child_size := child.size[axis]
			child_min_size := child.min_size[axis]
			if child_size == largest {
				child_size += size_to_add

				if axis == .X {
					child.size.x = child_size
				} else {
					child.size.y = child_size
				}

				if child_size <= child_min_size {
					child_size = child_min_size
					if axis == .X {
						child.size.x = child_size
					} else {
						child.size.y = child_size
					}
					unordered_remove(&shrinkables, idx)
				}
				remaining_size -= (child_size - prev_size)
			}
		}
	}

	for child in element.children {
		grow_child_elements_for_axis(child, axis)
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
		if err != nil {
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

// TODO(Thomas): This test could become much nicer if we make a better
// way of calculating the sizes, instead of manually doing it like now.
@(test)
test_fit_sizing :: proc(t: ^testing.T) {
	ctx := Context{}

	arena := virtual.Arena{}
	arena_buffer := make([]u8, 100 * 1024)
	arena_alloc_err := virtual.arena_init_buffer(&arena, arena_buffer)
	assert(arena_alloc_err == .None)
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)
	defer delete(arena_buffer)

	persistent_allocator := arena_allocator
	frame_allocator := arena_allocator

	// Left_To_Right layout direction
	{
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

		init(&ctx, persistent_allocator, frame_allocator)
		defer deinit(&ctx)

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

		panel_element := ctx.root_element.children[0]

		// assert panel size
		testing.expect_value(
			t,
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

	//Top_To_Bottom layout direction
	{
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

		init(&ctx, persistent_allocator, frame_allocator)
		defer deinit(&ctx)

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

		panel_element := ctx.root_element.children[0]

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
}

@(test)
test_grow_sizing :: proc(t: ^testing.T) {

	ctx := Context{}

	arena := virtual.Arena{}
	arena_buffer := make([]u8, 100 * 1024)
	arena_alloc_err := virtual.arena_init_buffer(&arena, arena_buffer)
	assert(arena_alloc_err == .None)
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)
	defer delete(arena_buffer)

	persistent_allocator := arena_allocator
	frame_allocator := arena_allocator

	// Left_To_Right layout direction
	{
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

		init(&ctx, persistent_allocator, frame_allocator)
		defer deinit(&ctx)

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

		panel_element := ctx.root_element.children[0]

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
	// Top_To_Bottom layout direction
	{
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

		init(&ctx, persistent_allocator, frame_allocator)
		defer deinit(&ctx)
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
		panel_element := ctx.root_element.children[0]

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
}
