package ui

import "core:log"
import "core:mem"
import "core:testing"

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

		if element.parent != nil {
			padding := element.padding
			element.size.x += padding.left + padding.right
			element.size.y += padding.top + padding.bottom
			child_gap := f32((len(element.parent.children) - 1)) * element.parent.child_gap
			if element.parent.layout_direction == .Left_To_Right {
				//element.size.x += child_gap
				element.parent.size.x += element.size.x + child_gap
				element.parent.size.y = max(element.size.y, element.parent.size.y)
			} else {
				//element.size.y += child_gap
				element.parent.size.x = max(element.size.x, element.parent.size.x)
				element.parent.size.y += element.size.y + child_gap
			}
		}
	}

	log.infof(
		"id_string: %s, size.x: %f, size.y: %f",
		element.id_string,
		element.size.x,
		element.size.y,
	)
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
			log.infof(
				"id_string: %s, len(parent.childen): %v",
				element.id_string,
				len(element.parent.children),
			)
		}

		// CONTINUE HERE:
		// Somehow caching the UI_Element causes the "panel"
		// in main to be 240 wide instead of 230. Investigate why.
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

@(test)
test_fit_sizing :: proc(t: ^testing.T) {
	ctx := Context{}
	persistent_allocator := context.temp_allocator
	frame_allocator := context.temp_allocator

	// Left_To_Right layout direction
	{
		init(&ctx, persistent_allocator, frame_allocator)
		defer deinit(&ctx)

		begin(&ctx)

		open_element(
			&ctx,
			"panel",
			Element_Config {
				sizing = {{kind = .Fit}, {kind = .Fit}},
				layout_direction = .Left_To_Right,
				padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
			},
		)
		{
			open_element(
				&ctx,
				"container_1",
				Element_Config {
					sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}},
				},
			)
			close_element(&ctx)
			open_element(
				&ctx,
				"container_2",
				Element_Config {
					sizing = {{kind = .Fixed, value = 50}, {kind = .Fixed, value = 150}},
				},
			)
			close_element(&ctx)
		}

		close_element(&ctx)
		end(&ctx)

		calculate_positions(ctx.root_element)

		panel_element := ctx.root_element.children[0]

		// assert panel size
		left_pad: f32 = 10
		right_pad: f32 = 10
		top_pad: f32 = 10
		bottom_pad: f32 = 10
		child_gap: f32 = 10
		testing.expect_value(t, panel_element.size.x, left_pad + 100 + child_gap + 50 + right_pad)
		testing.expect_value(t, panel_element.size.y, 150 + top_pad + bottom_pad)

		// assert panel positions
		testing.expect_value(t, panel_element.position.x, 0)
		testing.expect_value(t, panel_element.position.y, 0)

		// assert container_1 size
		container_1_element := panel_element.children[0]
		testing.expect_value(t, container_1_element.size.x, 100)
		testing.expect_value(t, container_1_element.size.y, 100)

		// asert container_1 position
		testing.expect_value(t, container_1_element.position.x, left_pad)
		testing.expect_value(t, container_1_element.position.y, top_pad)

		// assert container_2 size
		container_2_element := panel_element.children[1]
		testing.expect_value(t, container_2_element.size.x, 50)
		testing.expect_value(t, container_2_element.size.y, 150)

		// assert container_2 position
		testing.expect_value(
			t,
			container_2_element.position.x,
			container_1_element.position.x + container_1_element.size.x + child_gap,
		)
		testing.expect_value(t, container_2_element.position.y, top_pad)

	}
}
