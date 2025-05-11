package ui

import "core:log"
import "core:mem"
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
	size:             Vec2,
	sizing:           [2]Sizing,
	layout_direction: Layout_Direction,
	padding:          Padding,
	child_gap:        f32,
	children:         [dynamic]^UI_Element,
	color:            Color,
}

Sizing :: struct {
	kind:  Size_Kind,
	value: f32,
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

// TODO(Thomas): current parent probably has to be a pointer
open_element :: proc(ctx: ^Context, id: string, element_config: Element_Config) -> bool {

	// TODO(Thomas): Do something with the setting here
	element, element_ok := make_element(ctx, id)
	element.sizing = element_config.sizing
	element.layout_direction = element_config.layout_direction
	element.padding = element_config.padding
	element.child_gap = element_config.child_gap
	element.position.x = 0
	element.position.y = 0
	element.size.x = element.sizing[0].value
	element.size.y = element.sizing[1].value
	element.color = element_config.color
	assert(element_ok)

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
			element.size.x = calculate_element_size_for_axis(element, .X)
		}

		if element.sizing.y.kind == .Fit {
			element.size.y = calculate_element_size_for_axis(element, .Y)
		}

		if element.parent != nil {
			if element.parent.layout_direction == .Left_To_Right && element.sizing.x.kind == .Fit {
				element.parent.size.x += element.size.x
				element.parent.size.y = max(element.size.y, element.parent.size.y)
			} else if element.parent.layout_direction == .Top_To_Bottom &&
			   element.sizing.y.kind == .Fit {
				element.parent.size.x = max(element.size.x, element.parent.size.x)
				element.parent.size.y += element.size.y
			}
		}
	}
}

grow_child_elements :: proc(element: ^UI_Element) {
	remaining_width := element.size.x
	remaining_height := element.size.y
	remaining_width -= element.padding.left + element.padding.right
	remaining_height -= element.padding.top + element.padding.bottom

	child_gap := f32(len(element.children) - 1) * element.child_gap

	for child in element.children {
		remaining_width -= child.size.x
	}

	remaining_width -= child_gap

	for child in element.children {
		if child.sizing.x.kind == .Grow {
			child.size.x += remaining_width
		}

		if child.sizing.y.kind == .Grow {
			child.size.y += (remaining_height - child.size.y)
		}
	}

	for child in element.children {
		grow_child_elements(child)
	}
}

make_element :: proc(ctx: ^Context, id: string) -> (^UI_Element, bool) {

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
	persistent_allocator := context.temp_allocator
	frame_allocator := context.temp_allocator

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
