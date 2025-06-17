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

Alignment_X :: enum {
	Left,
	Center,
	Right,
}

Alignment_Y :: enum {
	Top,
	Center,
	Bottom,
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

Element_Kind :: enum {
	Container,
	Text,
}

Layout_Config :: struct {
	sizing:           [2]Sizing,
	padding:          Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	alignment_x:      Alignment_X,
	alignment_y:      Alignment_Y,
}

UI_Element :: struct {
	parent:      ^UI_Element,
	id_string:   string,
	position:    Vec2,
	min_size:    Vec2,
	max_size:    Vec2,
	size:        Vec2,
	layout:      Layout_Config,
	children:    [dynamic]^UI_Element,
	color:       Color,
	kind:        Element_Kind,
	text_config: Text_Element_Config,
	text_lines:  []Text_Line,
}

Sizing :: struct {
	kind:      Size_Kind,
	min_value: f32,
	max_value: f32,
	value:     f32,
}

Element_Config :: struct {
	layout: Layout_Config,
	color:  Color,
}

Text_Element_Config :: struct {
	data:        string,
	color:       Color,
	min_width:   f32,
	min_height:  f32,
	max_width:   f32,
	max_height:  f32,
	alignment_x: Alignment_X,
	alignment_y: Alignment_Y,
}

calc_child_gap := #force_inline proc(element: UI_Element) -> f32 {
	if len(element.children) == 0 {
		return 0
	} else {
		return f32(len(element.children) - 1) * element.layout.child_gap
	}
}

// Size of the element is capped at it's max size.
calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.layout.padding
	padding_sum := axis == .X ? padding.left + padding.right : padding.top + padding.bottom
	size: f32 = 0

	primary_axis := is_primary_axis(element^, axis)
	if primary_axis {
		child_sum_size: f32 = 0
		for child in element.children {
			child_sum_size += child.size[axis]
		}
		child_gap := calc_child_gap(element^)
		if size + child_sum_size + child_gap <= element.max_size[axis] {
			size += child_sum_size + child_gap
		} else {
			size = element.max_size[axis]
		}
	} else {
		for child in element.children {
			max_value := max(size, child.size[axis])
			if max_value <= element.max_size[axis] {
				size = max_value
			} else {
				size = element.max_size[axis]
			}
		}
	}

	total_size := size + padding_sum

	if total_size <= element.min_size[axis] {
		return element.min_size[axis]
	} else if total_size <= element.max_size[axis] {
		return total_size
	} else {
		return element.max_size[axis]
	}
}

open_element :: proc(ctx: ^Context, id: string, element_config: Element_Config) -> bool {
	element, element_ok := make_element(ctx, id, .Container, element_config)
	assert(element_ok)

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

open_text_element :: proc(ctx: ^Context, id: string, text_config: Text_Element_Config) -> bool {
	text_metrics := ctx.measure_text_proc(text_config.data, ctx.font_id, ctx.font_user_data)
	element, element_ok := make_element(
		ctx,
		id,
		.Text,
		Element_Config {
			layout = {
				sizing = {
					{
						kind = .Grow,
						min_value = text_config.min_width,
						value = text_metrics.width,
						max_value = text_config.max_width,
					},
					{
						kind = .Grow,
						min_value = text_config.min_height,
						value = text_metrics.line_height,
						max_value = text_config.max_height,
					},
				},
				alignment_x = text_config.alignment_x,
				alignment_y = text_config.alignment_y,
			},
		},
	)
	assert(element_ok)

	element.text_config = text_config

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent
	}
}

container :: proc(
	ctx: ^Context,
	id: string,
	config: Element_Config,
	body: proc(ctx: ^Context) = nil,
) {
	if open_element(ctx, id, config) {
		defer close_element(ctx)
		if body != nil {
			body(ctx)
		}
	}
}

text :: proc(ctx: ^Context, id: string, config: Text_Element_Config) {
	if open_text_element(ctx, id, config) {
		close_element(ctx)
	}
}

fit_size_axis :: proc(element: ^UI_Element, axis: Axis2) {
	for child in element.children {
		fit_size_axis(child, axis)
	}

	if element.layout.sizing[axis].kind == .Fit {
		calc_element_fit_size_for_axis(element, axis)
	}
}

update_parent_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent
	if axis == .X && parent.layout.layout_direction == .Left_To_Right {
		parent.size.x += element.size.x
		parent.min_size.x += element.min_size.x
		parent.size.y = max(element.size.y, parent.size.y)
		parent.min_size.y = max(element.min_size.y, parent.min_size.y)

	} else if axis == .Y && parent.layout.layout_direction == .Top_To_Bottom {
		parent.size.x = max(element.size.x, parent.size.x)
		parent.min_size.x = max(element.min_size.x, parent.min_size.x)
		parent.size.y += element.size.y
		parent.min_size.y += element.min_size.y
	}
}

calc_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	element.size[axis] = calculate_element_size_for_axis(element, axis)

	if element.parent != nil {
		update_parent_element_fit_size_for_axis(element, axis)
	}
}

calc_remaining_size :: #force_inline proc(element: UI_Element, axis: Axis2) -> f32 {
	padding_sum :=
		axis == .X ? element.layout.padding.left + element.layout.padding.right : element.layout.padding.top + element.layout.padding.bottom

	remaining_size := element.size[axis] - padding_sum
	return remaining_size
}

is_primary_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_primary_axis :=
		(axis == .X && element.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.layout.layout_direction == .Top_To_Bottom)

	return is_primary_axis
}

@(private)
GROW_ITER_MAX :: 32
@(private)
SHRINK_ITER_MAX :: 32

// TODO(Thomas): Pretty sure this procedure can be simplified, especially the
// iterating over growables part. Also, it can be merged together with the
// shrink procedure for one unified procedure that does both max and min sizing.
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
			size_kind := child.layout.sizing[axis].kind

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
			size_kind := child.layout.sizing[axis].kind
			if size_kind == .Grow {
				child.size[axis] += (remaining_size - child.size[axis])
			}
		}
	}

	grow_iter := 0
	// Process growable children, only if we have collected any
	for remaining_size > EPSILON && len(small_array.slice(&growables)) > 0 {
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
		size_to_add = min(size_to_add, remaining_size / f32(len(small_array.slice(&growables))))

		// New implementation for max size on .Grow sizing
		#reverse for child, idx in small_array.slice(&growables) {
			prev_size := child.size[axis]
			child_size := child.size[axis]
			child_max_size := child.max_size[axis]
			if approx_equal(child_size, smallest, EPSILON) {
				child_size += size_to_add
				child.size[axis] = child_size
				if child_size >= child_max_size {
					child_size = child_max_size
					child.size[axis] = child_size
					small_array.unordered_remove(&growables, idx)
				}
				remaining_size -= (child_size - prev_size)
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
			size_kind := child.layout.sizing[axis].kind
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

		// NOTE(Thomas): We iterate in reverse order to ensure that the idx
		// after one removal will be valid.
		#reverse for child, idx in small_array.slice(&shrinkables) {
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


wrap_text :: proc(ctx: ^Context, element: ^UI_Element, allocator: mem.Allocator) {

	if element.kind == .Text {
		text := element.text_config.data
		tokens := make([dynamic]Text_Token, allocator)
		tokenize_text(ctx, text, ctx.font_id, &tokens)

		lines := make([dynamic]Text_Line, allocator)
		layout_lines(ctx, text, tokens[:], element.size.x, &lines)

		element.text_lines = lines[:]
		text_height: f32 = 0
		for line in lines {
			text_height += line.height
		}
		element.size.y += text_height
	}

	for child in element.children {
		wrap_text(ctx, child, allocator)
	}
}

make_element :: proc(
	ctx: ^Context,
	id: string,
	kind: Element_Kind,
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

	// TODO(Thomas): Prune which of these fields actually has to be set every frame
	// or which can be cached.
	// We need to set this fields every frame
	// TODO(Thomas): Why the heck just not set element.layout = element_config.layout?????
	element.kind = kind
	element.layout.sizing = element_config.layout.sizing
	element.layout.layout_direction = element_config.layout.layout_direction
	element.layout.padding = element_config.layout.padding
	element.layout.child_gap = element_config.layout.child_gap
	element.layout.alignment_x = element_config.layout.alignment_x
	element.layout.alignment_y = element_config.layout.alignment_y
	element.position.x = 0
	element.position.y = 0
	element.color = element_config.color

	element.size.x = element.layout.sizing.x.value
	element.size.y = element.layout.sizing.y.value

	element.min_size.x = element_config.layout.sizing.x.min_value
	element.min_size.y = element_config.layout.sizing.y.min_value

	// NOTE(Thomas): A max value of 0 doesn't make sense, so we assume that
	// the user wants it to just fit whatever, so we set it to f32 max value
	if approx_equal(element_config.layout.sizing.x.max_value, 0, 0.001) {
		element.max_size.x = math.F32_MAX
	} else {
		element.max_size.x = element_config.layout.sizing.x.max_value
	}

	if approx_equal(element_config.layout.sizing.y.max_value, 0, 0.001) {
		element.max_size.y = math.F32_MAX
	} else {
		element.max_size.y = element_config.layout.sizing.y.max_value
	}

	return element, true
}

calculate_positions_and_alignment :: proc(parent: ^UI_Element) {
	if parent == nil {
		return
	}
	parent_child_gap := calc_child_gap(parent^)

	// Calculate content area bounds
	content_start_x := parent.position.x + parent.layout.padding.left
	content_start_y := parent.position.y + parent.layout.padding.top

	layout_direction := parent.layout.layout_direction
	if layout_direction == .Left_To_Right {
		// Calculate total width used by all children
		total_children_width: f32 = 0
		for child in parent.children {
			total_children_width += child.size.x
		}

		// Calculate remaining space after children and gaps
		remaining_size_x :=
			parent.size.x -
			parent.layout.padding.left -
			parent.layout.padding.right -
			parent_child_gap -
			total_children_width

		// Calculate starting X position based on alignment
		start_x := content_start_x
		switch parent.layout.alignment_x {
		case .Left:
			start_x = content_start_x
		case .Center:
			start_x = content_start_x + (remaining_size_x / 2)
		case .Right:
			start_x = content_start_x + remaining_size_x
		}

		current_x := start_x
		for i in 0 ..< len(parent.children) {
			child := parent.children[i]
			child.position.x = current_x

			// Y position alignment, in horizontal layout
			// each child can have different alignment offset on the y axis
			remaining_size_y :=
				parent.size.y -
				parent.layout.padding.top -
				parent.layout.padding.bottom -
				child.size.y

			switch parent.layout.alignment_y {
			case .Top:
				child.position.y = content_start_y
			case .Center:
				child.position.y = content_start_y + (remaining_size_y / 2)
			case .Bottom:
				child.position.y = content_start_y + remaining_size_y
			}

			// Move to next child position
			if i < len(parent.children) - 1 {
				current_x += child.size.x + parent.layout.child_gap
			}
		}

	} else {

		// Calculate total height used by all children
		total_children_height: f32 = 0
		for child in parent.children {
			total_children_height += child.size.y
		}

		// Calculate remaining space after children and gaps
		remaining_size_y :=
			parent.size.y -
			parent.layout.padding.top -
			parent.layout.padding.bottom -
			parent_child_gap -
			total_children_height

		// Calculate starting Y position based on alignment
		start_y := content_start_y
		switch parent.layout.alignment_y {
		case .Top:
			start_y = content_start_y
		case .Center:
			start_y = content_start_y + (remaining_size_y / 2)
		case .Bottom:
			start_y = content_start_y + remaining_size_y
		}

		current_y := start_y
		for i in 0 ..< len(parent.children) {
			child := parent.children[i]
			child.position.y = current_y

			// X position alignment, in vertical layout
			// each child can have different alignment offset on the x axis
			remaining_size_x :=
				parent.size.x -
				parent.layout.padding.left -
				parent.layout.padding.right -
				child.size.x

			switch parent.layout.alignment_x {
			case .Left:
				child.position.x = content_start_x
			case .Center:
				child.position.x = content_start_x + (remaining_size_x / 2)
			case .Right:
				child.position.x = content_start_x + remaining_size_x
			}

			// Move to next child position
			if i < len(parent.children) - 1 {
				current_y += child.size.y + parent.layout.child_gap
			}
		}
	}
	// Recursively calculate positions for all children's children
	for child in parent.children {
		calculate_positions_and_alignment(child)
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
	ctx:                        Context,
	persistent_arena:           virtual.Arena,
	persistent_arena_allocator: mem.Allocator,
	frame_arena:                virtual.Arena,
	frame_arena_allocator:      mem.Allocator,
}

// NOTE(Thomas): The reason we're returning a pointer to the 
// Test_Environment here is to make sure that the allocators live
// long enough.
setup_test_environment :: proc() -> ^Test_Environment {
	env := new(Test_Environment)

	// Setup arena and allocator
	env.persistent_arena = virtual.Arena{}
	persistent_arena_alloc_err := virtual.arena_init_static(&env.persistent_arena)
	assert(persistent_arena_alloc_err == .None)
	env.persistent_arena_allocator = virtual.arena_allocator(&env.persistent_arena)

	env.frame_arena = virtual.Arena{}
	frame_arena_alloc_err := virtual.arena_init_static(&env.frame_arena)
	assert(frame_arena_alloc_err == .None)
	env.frame_arena_allocator = virtual.arena_allocator(&env.frame_arena)

	init(&env.ctx, env.persistent_arena_allocator, env.frame_arena_allocator)

	return env
}

cleanup_test_environment :: proc(env: ^Test_Environment) {
	deinit(&env.ctx)
	free_all(env.persistent_arena_allocator)
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
test_fit_container_no_children :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 10,
		top    = 20,
		right  = 15,
		bottom = 25,
	}

	begin(&ctx)
	open_element(
		&ctx,
		"empty_panel",
		Element_Config {
			layout = {
				sizing           = {{kind = .Fit}, {kind = .Fit}},
				layout_direction = .Left_To_Right,
				padding          = panel_padding,
				child_gap        = 5, // child_gap is irrelevant with 0 children
			},
		},
	)
	close_element(&ctx)
	end(&ctx)

	calculate_positions_and_alignment(ctx.root_element)

	panel := find_element_by_id(ctx.root_element, "empty_panel")
	testing.expect(t, panel != nil, "Panel 'empty_panel' not found")

	// Expected size is just the sum of padding.
	expected_size := Vec2 {
		panel_padding.left + panel_padding.right, // 10 + 15 = 25
		panel_padding.top + panel_padding.bottom, // 20 + 25 = 45
	}
	expect_element_size(t, panel, expected_size)

	// Assuming panel is the first element, its position is (0,0) relative to root/viewport.
	expect_element_pos(t, panel, {0, 0})
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
	largest_container_y: f32 = 150

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			layout = {
				sizing = {{kind = .Fit}, {kind = .Fit}},
				layout_direction = .Left_To_Right,
				padding = panel_padding,
				child_gap = 10,
			},
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_1_size.x},
						{kind = .Fixed, value = container_1_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_2_size.x},
						{kind = .Fixed, value = container_2_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_3_size.x},
						{kind = .Fixed, value = container_3_size.y},
					},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions_and_alignment(ctx.root_element)

	panel_element := find_element_by_id(ctx.root_element, "panel")
	testing.expect(t, panel_element != nil)

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

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			layout = {
				sizing = {{kind = .Fit}, {kind = .Fit}},
				layout_direction = .Top_To_Bottom,
				padding = panel_padding,
				child_gap = 10,
			},
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_1_size.x},
						{kind = .Fixed, value = container_1_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_2_size.x},
						{kind = .Fixed, value = container_2_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_3_size.x},
						{kind = .Fixed, value = container_3_size.y},
					},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions_and_alignment(ctx.root_element)

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
	container_3_size := Vec2{150, 150}
	container_2_size := Vec2 {
		panel_size.x -
		container_1_size.x -
		container_3_size.x -
		2 * panel_child_gap -
		panel_padding.left -
		panel_padding.right,
		panel_size.y - panel_padding.top - panel_padding.bottom,
	}

	begin(&ctx)

	open_element(
		&ctx,
		"panel",
		Element_Config {
			layout = {
				sizing = {
					{kind = .Fixed, value = panel_size.x},
					{kind = .Fixed, value = panel_size.y},
				},
				layout_direction = .Left_To_Right,
				padding = panel_padding,
				child_gap = 10,
			},
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_1_size.x},
						{kind = .Fixed, value = container_1_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_3_size.x},
						{kind = .Fixed, value = container_3_size.y},
					},
				},
			},
		)
		close_element(&ctx)
	}

	close_element(&ctx)
	end(&ctx)

	calculate_positions_and_alignment(ctx.root_element)

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
test_grow_sizing_max_value_ltr :: proc(t: ^testing.T) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)
	ctx := test_env.ctx

	panel_padding := Padding {
		left   = 11,
		top    = 12,
		right  = 13,
		bottom = 14,
	}
	panel_child_gap: f32 = 10

	panel_size := Vec2{600, 400}
	container_1_expected_size := Vec2{150, panel_size.y - panel_padding.top - panel_padding.bottom}
	container_3_size := Vec2{150, 150}
	container_2_expected_size := Vec2{50, panel_size.y - panel_padding.top - panel_padding.bottom}

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			layout = {
				sizing = {
					{kind = .Fixed, value = panel_size.x},
					{kind = .Fixed, value = panel_size.y},
				},
				layout_direction = .Left_To_Right,
				padding = panel_padding,
				child_gap = panel_child_gap,
			},
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config{layout = {sizing = {{kind = .Grow, max_value = 150}, {kind = .Grow}}}},
		)
		close_element(&ctx)

		open_element(
			&ctx,
			"container_2",
			Element_Config{layout = {sizing = {{kind = .Grow, max_value = 50}, {kind = .Grow}}}},
		)
		close_element(&ctx)

		open_element(
			&ctx,
			"container_3",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_3_size.x},
						{kind = .Fixed, value = container_3_size.y},
					},
				},
			},
		)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)

	calculate_positions_and_alignment(ctx.root_element)
	panel_element := find_element_by_id(ctx.root_element, "panel")

	// assert panel size
	testing.expect_value(t, panel_element.size.x, panel_size.x)
	testing.expect_value(t, panel_element.size.y, panel_size.y)

	// assert panel positions
	testing.expect_value(t, panel_element.position.x, 0)
	testing.expect_value(t, panel_element.position.y, 0)

	// assert container_1 size
	container_1_element := panel_element.children[0]
	testing.expect_value(t, container_1_element.size.x, container_1_expected_size.x)
	testing.expect_value(t, container_1_element.size.y, container_1_expected_size.y)

	// assert container_1 position
	testing.expect_value(t, container_1_element.position.x, panel_padding.left)
	testing.expect_value(t, container_1_element.position.y, panel_padding.top)

	// assert container_2 size
	container_2_element := panel_element.children[1]
	testing.expect_value(t, container_2_element.size.x, container_2_expected_size.x)
	testing.expect_value(t, container_2_element.size.y, container_2_expected_size.y)

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
	container_3_size := Vec2{150, 150}
	container_2_size := Vec2 {
		panel_size.x - panel_padding.left - panel_padding.right,
		panel_size.y -
		container_1_size.y -
		container_3_size.y -
		2 * panel_child_gap -
		panel_padding.top -
		panel_padding.bottom,
	}

	begin(&ctx)
	open_element(
		&ctx,
		"panel",
		Element_Config {
			layout = {
				sizing = {
					{kind = .Fixed, value = panel_size.x},
					{kind = .Fixed, value = panel_size.y},
				},
				layout_direction = .Top_To_Bottom,
				padding = panel_padding,
				child_gap = 10,
			},
		},
	)
	{
		open_element(
			&ctx,
			"container_1",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_1_size.x},
						{kind = .Fixed, value = container_1_size.y},
					},
				},
			},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_2",
			Element_Config{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
		)
		close_element(&ctx)
		open_element(
			&ctx,
			"container_3",
			Element_Config {
				layout = {
					sizing = {
						{kind = .Fixed, value = container_3_size.x},
						{kind = .Fixed, value = container_3_size.y},
					},
				},
			},
		)
		close_element(&ctx)
	}
	close_element(&ctx)
	end(&ctx)
	calculate_positions_and_alignment(ctx.root_element)
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
	testing.expect_value(t, container_2_element.size.x, container_2_size.x)
	testing.expect_value(t, container_2_element.size.y, container_2_size.y)

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
