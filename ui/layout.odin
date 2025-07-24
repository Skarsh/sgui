package ui

import "core:container/small_array"
import "core:fmt"
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
	Fit,
	Fixed,
	Grow,
	Percentage_Of_Parent,
}

Padding :: struct {
	left:   f32,
	right:  f32,
	top:    f32,
	bottom: f32,
}

Text_Data :: struct {
	text:  string,
	lines: []Text_Line,
}

Image_Data :: struct {
	data: rawptr,
}

Element_Content :: struct {
	text_data:  Text_Data,
	image_data: Image_Data,
}

Layout_Config :: struct {
	sizing:           [2]Sizing,
	padding:          Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	alignment_x:      Alignment_X,
	alignment_y:      Alignment_Y,
	text_padding:     Padding,
	text_alignment_x: Alignment_X,
	text_alignment_y: Alignment_Y,
}

Clip_Config :: struct {
	clip_axes: [2]bool,
}

// TODO(Thomas): Redundant data between the Element_Config and fields in this struct
// e.g. sizes, etc.
UI_Element :: struct {
	parent:    ^UI_Element,
	id_string: string,
	position:  Vec2,
	min_size:  Vec2,
	max_size:  Vec2,
	size:      Vec2,
	config:    Element_Config,
	children:  [dynamic]^UI_Element,
	color:     Color,
	z_index:   i32,
	hot:       f32,
	active:    f32,
	last_comm: Comm,
}

Sizing :: struct {
	kind:      Size_Kind,
	min_value: f32,
	max_value: f32,
	value:     f32,
}

Element_Config :: struct {
	layout:           Layout_Config,
	background_color: Color,
	clip:             Clip_Config,
	capability_flags: Capability_Flags,
	content:          Element_Content,
}

// TODO(Thomas): A lot of duplicated code between this and the text procedure!
// An idea would be to have the text procedure just make an element, and then
// equip the string. When style stacks are implemented, it could push those onto
// aswell.
element_equip_text :: proc(ctx: ^Context, element: ^UI_Element, text: string) {
	element.config.capability_flags |= {.Text}

	// NOTE(Thomas): We need to pre-calculate the line widths to make
	// sure that the element gets a reasonable preferred sizing.
	// We do this by doing the same line layout calculation we do in 
	// `wrap_text`, but we pass in a very large `max_width`, so we
	// will only split the lines based on `\n`.
	// We need to do this before we're doing any proper sizing calculations
	// so we're not screwing with that.
	// TODO(Thomas): Cache the tokenization, we don't have to redo
	// this for the `wrap_text` procedure.
	// TODO(Thomas): Calculate a reasonable min_size for the text element too.
	// Something like the smallest word in the tokens would make sense.
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)

	tokenize_text(ctx, text, ctx.font_id, &tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)

	layout_lines(ctx, text, tokens[:], math.F32_MAX, &lines)

	largest_line_width: f32 = 0
	text_height: f32 = 0
	for line in lines {
		if line.width > largest_line_width {
			largest_line_width = line.width
		}
		text_height += line.height
	}

	min_width := element.min_size.x
	min_height := element.min_size.y

	max_width := element.max_size.x
	max_height := element.max_size.y

	text_padding := element.config.layout.text_padding
	width := largest_line_width + text_padding.left + text_padding.right
	height := text_height + text_padding.top + text_padding.bottom

	if width < min_width {
		width = min_width
	} else if width > max_width {
		width = max_width
	}

	if height < min_height {
		height = min_height
	} else if height > max_height {
		height = max_height
	}

	element.size.x = width
	element.size.y = height

	element.config.layout.sizing.x = {
		kind      = .Grow,
		min_value = min_width,
		value     = width,
		max_value = max_width,
	}

	element.config.layout.sizing.y = {
		kind      = .Grow,
		min_value = min_height,
		value     = height,
		max_value = max_height,
	}

	element.config.content.text_data = Text_Data {
		text = text,
	}
}

calc_child_gap := #force_inline proc(element: UI_Element) -> f32 {
	if len(element.children) == 0 {
		return 0
	} else {
		return f32(len(element.children) - 1) * element.config.layout.child_gap
	}
}

// Size of the element is capped at it's max size.
calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.config.layout.padding
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

open_element :: proc(
	ctx: ^Context,
	id: string,
	element_config: Element_Config,
) -> (
	^UI_Element,
	bool,
) {
	element, element_ok := make_element(ctx, id, element_config)
	assert(element_ok)

	if push(&ctx.element_stack, element) {
		element.z_index = ctx.element_stack.top
	} else {
		return nil, false
	}
	ctx.current_parent = element
	return element, true
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent
	}
}

container :: proc {
	container_data,
	container_empty,
}

container_empty :: proc(
	ctx: ^Context,
	id: string,
	config: Element_Config,
	empty_body_proc: proc(ctx: ^Context) = nil,
) {
	_, open_ok := open_element(ctx, id, config)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if empty_body_proc != nil {
			empty_body_proc(ctx)
		}
	}
}

container_data :: proc(
	ctx: ^Context,
	id: string,
	config: Element_Config,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) {
	_, open_ok := open_element(ctx, id, config)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if body != nil {
			body(ctx, data)
		}
	}
}

text :: proc(
	ctx: ^Context,
	id: string,
	text: string,
	min_width: f32 = 0,
	min_height: f32 = 0,
	max_width: f32 = math.F32_MAX,
	max_height: f32 = math.F32_MAX,
	text_padding: Padding = {},
	text_alignment_x := Alignment_X.Left,
	text_alignment_y := Alignment_Y.Top,
) {
	assert(min_width >= 0)
	assert(min_height >= 0)

	config := Element_Config{}
	config.layout.text_padding = text_padding
	config.layout.sizing = {
		{min_value = min_width, max_value = max_width},
		{min_value = min_height, max_value = max_height},
	}
	config.capability_flags |= {.Text}
	config.layout.text_alignment_x = text_alignment_x
	config.layout.text_alignment_y = text_alignment_y

	element, open_ok := open_element(ctx, id, config)
	assert(open_ok)
	if open_ok {
		element_equip_text(ctx, element, text)
		close_element(ctx)
	}
}

fit_size_axis :: proc(element: ^UI_Element, axis: Axis2) {
	for child in element.children {
		fit_size_axis(child, axis)
	}

	if element.config.layout.sizing[axis].kind == .Fit {
		calc_element_fit_size_for_axis(element, axis)
	}
}

update_parent_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent
	if axis == .X && parent.config.layout.layout_direction == .Left_To_Right {
		parent.size.x += element.size.x
		parent.min_size.x += element.min_size.x
		parent.size.y = max(element.size.y, parent.size.y)
		parent.min_size.y = max(element.min_size.y, parent.min_size.y)

	} else if axis == .Y && parent.config.layout.layout_direction == .Top_To_Bottom {
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
	padding := element.config.layout.padding
	padding_sum := axis == .X ? padding.left + padding.right : padding.top + padding.bottom

	remaining_size := element.size[axis] - padding_sum
	return remaining_size
}

is_primary_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_primary_axis :=
		(axis == .X && element.config.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.config.layout.layout_direction == .Top_To_Bottom)

	return is_primary_axis
}

@(private)
RESIZE_ITER_MAX :: 32
// Combined grow and shrink size procedure
resize_child_elements_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	// NOTE(Thomas): The reason I went for using a Small_Array here instead
	// of just a normal [dynamic]^UI_Element array is because dynamic arrays
	// can have issues with arena allocators if growing, which would be the case
	// if using contex.temp_allocator. So I decided to just go for Small_Array until 
	// I have figured more on how I want to do this. swapping out for Small_Array was very
	// simple, and shouldn't be a problem to go back if we want to use something like a 
	// virtual static arena ourselves to ensure the dynamic array stays in place.
	resizables := small_array.Small_Array(1024, ^UI_Element){}

	remaining_size := calc_remaining_size(element^, axis)

	primary_axis := is_primary_axis(element^, axis)

	is_growing := remaining_size > 0

	if primary_axis {
		for child in element.children {
			size_kind := child.config.layout.sizing[axis].kind
			remaining_size -= child.size[axis]

			if size_kind == .Grow {
				resizable := false

				if is_growing {
					resizable = child.size[axis] < child.max_size[axis]
				} else {
					resizable = child.size[axis] > child.min_size[axis]
				}

				if resizable {
					small_array.push(&resizables, child)
				}
			}
		}
		child_gap := calc_child_gap(element^)
		remaining_size -= child_gap
	} else {
		// Non-primary axis
		for child in element.children {
			// In then non-primary axis case, the child should just grow
			// or shrink to match the size of the parent in that direction.
			size_kind := child.config.layout.sizing[axis].kind
			if size_kind == .Grow {
				// This works because if remaining_size is positive, we're growing
				// and we'll add size to the child. 
				// If remaining_size is negative, we need to shrink the child
				// so we'll be adding a negative number to the size, effectively shrinking it.
				child.size[axis] += (remaining_size - child.size[axis])
			}
		}
	}

	resize_iter := 0
	for !approx_equal(remaining_size, 0, EPSILON) && len(small_array.slice(&resizables)) > 0 {
		assert(resize_iter < RESIZE_ITER_MAX)
		resize_iter += 1

		size_to_distribute := remaining_size
		if is_growing {
			smallest := small_array.get(resizables, 0).size[axis]
			second_smallest := math.INF_F32

			for child in small_array.slice(&resizables) {
				child_size := child.size[axis]
				if child_size < smallest {
					second_smallest = smallest
					smallest = child_size
				} else if child_size > smallest {
					second_smallest = min(second_smallest, child_size)
					size_to_distribute = second_smallest - smallest
				}
			}

			size_to_distribute = min(
				size_to_distribute,
				remaining_size / f32(len(small_array.slice(&resizables))),
			)

			// NOTE(Thomas): We iterate in reverse order to ensure that the idx
			// after one removal will be valid.
			#reverse for child, idx in small_array.slice(&resizables) {
				prev_size := child.size[axis]
				next_size := child.size[axis]
				child_max_size := child.max_size[axis]
				if approx_equal(next_size, smallest, EPSILON) {
					next_size += size_to_distribute
					child.size[axis] = next_size
					if next_size >= child_max_size {
						next_size = child_max_size
						child.size[axis] = next_size
						small_array.unordered_remove(&resizables, idx)
					}
					remaining_size -= (next_size - prev_size)
				}
			}
		} else {
			largest := small_array.get(resizables, 0).size[axis]
			second_largest := math.NEG_INF_F32

			for child in small_array.slice(&resizables) {
				child_size := child.size[axis]
				if child_size > largest {
					second_largest = largest
					largest = child_size
				} else if child_size < largest {
					second_largest = max(second_largest, child_size)
					size_to_distribute = second_largest - largest
				}
			}

			size_to_distribute = max(
				size_to_distribute,
				remaining_size / f32(len(small_array.slice(&resizables))),
			)

			#reverse for child, idx in small_array.slice(&resizables) {
				prev_size := child.size[axis]
				next_size := child.size[axis]
				child_min_size := child.min_size[axis]
				if approx_equal(next_size, largest, EPSILON) {
					next_size += size_to_distribute
					child.size[axis] = next_size

					if next_size <= child_min_size {
						next_size = child_min_size
						child.size[axis] = next_size
						small_array.unordered_remove(&resizables, idx)
					}
					remaining_size -= (next_size - prev_size)
				}
			}
		}
	}

	for child in element.children {
		resize_child_elements_for_axis(child, axis)
	}
}

resolve_percentage_sizing :: proc(element: ^UI_Element, axis: Axis2) {
	if element == nil {
		return
	}

	parent_content_size: Vec2
	if element.parent != nil {
		parent_padding := element.parent.config.layout.padding
		parent_content_size.x = element.parent.size.x - parent_padding.left - parent_padding.right
		parent_content_size.y = element.parent.size.y - parent_padding.top - parent_padding.bottom

		sizing_info := element.config.layout.sizing[axis]
		if sizing_info.kind == .Percentage_Of_Parent {
			percentage := sizing_info.value
			element.size[axis] = parent_content_size[axis] * percentage
		}
	}

	for child in element.children {
		resolve_percentage_sizing(child, axis)
	}

}

wrap_text :: proc(ctx: ^Context, element: ^UI_Element, allocator: mem.Allocator) {

	if .Text in element.config.capability_flags {
		text_padding := element.config.layout.text_padding
		text := element.config.content.text_data.text
		tokens := make([dynamic]Text_Token, allocator)
		tokenize_text(ctx, text, ctx.font_id, &tokens)

		lines := make([dynamic]Text_Line, allocator)
		available_width := element.size.x - text_padding.left - text_padding.right
		layout_lines(ctx, text, tokens[:], available_width, &lines)

		element.config.content.text_data.lines = lines[:]
		text_height: f32 = 0
		for line in lines {
			text_height += line.height
		}
		final_height := text_height + text_padding.top + text_padding.bottom
		element.size.y = math.clamp(final_height, element.min_size.y, element.max_size.y)
	}

	for child in element.children {
		wrap_text(ctx, child, allocator)
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

	// TODO(Thomas): Prune which of these fields actually has to be set every frame
	// or which can be cached.
	// We need to set this fields every frame
	// TODO(Thomas): Every field that is set from the config here is essentially
	// redundant. We should probably just set the config and then use that for further
	// calculations? 
	element.color = element_config.background_color

	element.size.x = element_config.layout.sizing.x.value
	element.size.y = element_config.layout.sizing.y.value

	element.min_size.x = element_config.layout.sizing.x.min_value
	element.min_size.y = element_config.layout.sizing.y.min_value

	element.config = element_config

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
	content_start_x := parent.position.x + parent.config.layout.padding.left
	content_start_y := parent.position.y + parent.config.layout.padding.top

	layout_direction := parent.config.layout.layout_direction
	if layout_direction == .Left_To_Right {
		// Calculate total width used by all children
		total_children_width: f32 = 0
		for child in parent.children {
			total_children_width += child.size.x
		}

		// Calculate remaining space after children and gaps
		padding := parent.config.layout.padding
		remaining_size_x :=
			parent.size.x - padding.left - padding.right - parent_child_gap - total_children_width

		// Calculate starting X position based on alignment
		start_x := content_start_x
		switch parent.config.layout.alignment_x {
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
			remaining_size_y := parent.size.y - padding.top - padding.bottom - child.size.y

			switch parent.config.layout.alignment_y {
			case .Top:
				child.position.y = content_start_y
			case .Center:
				child.position.y = content_start_y + (remaining_size_y / 2)
			case .Bottom:
				child.position.y = content_start_y + remaining_size_y
			}

			// Move to next child position
			if i < len(parent.children) - 1 {
				current_x += child.size.x + parent.config.layout.child_gap
			}
		}

	} else {

		// Calculate total height used by all children
		total_children_height: f32 = 0
		for child in parent.children {
			total_children_height += child.size.y
		}

		// Calculate remaining space after children and gaps
		padding := parent.config.layout.padding
		remaining_size_y :=
			parent.size.y - padding.top - padding.bottom - parent_child_gap - total_children_height

		// Calculate starting Y position based on alignment
		start_y := content_start_y
		switch parent.config.layout.alignment_y {
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
			remaining_size_x := parent.size.x - padding.left - padding.right - child.size.x

			switch parent.config.layout.alignment_x {
			case .Left:
				child.position.x = content_start_x
			case .Center:
				child.position.x = content_start_x + (remaining_size_x / 2)
			case .Right:
				child.position.x = content_start_x + remaining_size_x
			}

			// Move to next child position
			if i < len(parent.children) - 1 {
				current_y += child.size.y + parent.config.layout.child_gap
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

// Helper to print all the element_ids in the hierarchy
print_element_hierarchy :: proc(root: ^UI_Element) {
	if root == nil {
		return
	}

	fmt.printfln("%v", root.id_string)

	for child in root.children {
		print_element_hierarchy(child)
	}
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

	init(&env.ctx, env.persistent_arena_allocator, env.frame_arena_allocator, {0, 0})

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

Expected_Element :: struct {
	id:       string,
	pos:      Vec2,
	size:     Vec2,
	children: []Expected_Element,
}

run_layout_test :: proc(
	t: ^testing.T,
	build_ui: proc(ctx: ^Context, data: ^$T),
	verify: proc(t: ^testing.T, root: ^UI_Element, data: ^T),
	data: ^T,
) {
	test_env := setup_test_environment()
	defer cleanup_test_environment(test_env)

	ctx := &test_env.ctx

	set_text_measurement_callbacks(ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	begin(ctx)
	build_ui(ctx, data)
	end(ctx)

	verify(t, ctx.root_element, data)
}

expect_layout :: proc(
	t: ^testing.T,
	parent_element: ^UI_Element,
	expected: Expected_Element,
	epsilon: f32 = EPSILON,
) {
	// Find the actual element in the UI tree corresponding to the expected ID
	element_to_check := find_element_by_id(parent_element, expected.id)

	// Fail the test if the element doesn't exist
	if element_to_check == nil {
		testing.fail_now(t, fmt.tprintf("Element with id '%s' not found in layout", expected.id))
	}

	// Compare size and position with a small tolerance
	size_ok := approx_equal_vec2(element_to_check.size, expected.size, epsilon)
	pos_ok := approx_equal_vec2(element_to_check.position, expected.pos, epsilon)

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
		expect_layout(t, element_to_check, child, epsilon)
	}
}

@(test)
test_fit_container_no_children :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding: Padding,
	}

	test_data := Test_Data {
		panel_padding = Padding{left = 10, top = 20, right = 15, bottom = 25},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"empty_panel",
			{
				layout = {
					sizing           = {{kind = .Fit}, {kind = .Fit}},
					layout_direction = .Left_To_Right,
					padding          = data.panel_padding,
					child_gap        = 5, // child_gap is irrelevant with 0 children
				},
			},
		)
	}

	// --- 3. Define the Verification Logic --- 
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		size := Vec2 {
			data.panel_padding.left + data.panel_padding.right,
			data.panel_padding.top + data.panel_padding.bottom,
		}
		pos := Vec2{0, 0}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element{{id = "empty_panel", pos = pos, size = size}},
		}
		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_fit_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding:       Padding,
		panel_child_gap:     f32,
		container_1_size:    Vec2,
		container_2_size:    Vec2,
		container_3_size:    Vec2,
		largest_container_y: f32,
	}
	test_data := Test_Data {
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		container_1_size = Vec2{100, 100},
		container_2_size = Vec2{50, 150},
		container_3_size = Vec2{150, 150},
		largest_container_y = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {{kind = .Fit}, {kind = .Fit}},
					layout_direction = .Left_To_Right,
					padding = data.panel_padding,
					child_gap = 10,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_1_size.x},
								{kind = .Fixed, value = data.container_1_size.y},
							},
						},
					},
				)

				container(
					ctx,
					"container_2",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_2_size.x},
								{kind = .Fixed, value = data.container_2_size.y},
							},
						},
					},
				)

				container(
					ctx,
					"container_3",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_3_size.x},
								{kind = .Fixed, value = data.container_3_size.y},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic --- 
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {

		panel_size := Vec2 {
			data.panel_padding.left +
			data.panel_padding.right +
			data.panel_child_gap * 2 +
			data.container_1_size.x +
			data.container_2_size.x +
			data.container_3_size.x,
			data.largest_container_y + data.panel_padding.top + data.panel_padding.bottom,
		}

		panel_pos := Vec2{0, 0}
		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + data.container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + data.container_2_size.x + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = panel_pos,
					size = panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}
		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_fit_sizing_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding:       Padding,
		panel_child_gap:     f32,
		container_1_size:    Vec2,
		container_2_size:    Vec2,
		container_3_size:    Vec2,
		largest_container_x: f32,
	}
	test_data := Test_Data {
		panel_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		container_1_size = Vec2{100, 100},
		container_2_size = Vec2{50, 150},
		container_3_size = Vec2{150, 150},
		largest_container_x = 150,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {{kind = .Fit}, {kind = .Fit}},
					layout_direction = .Top_To_Bottom,
					padding = data.panel_padding,
					child_gap = 10,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_1_size.x},
								{kind = .Fixed, value = data.container_1_size.y},
							},
						},
					},
				)

				container(
					ctx,
					"container_2",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_2_size.x},
								{kind = .Fixed, value = data.container_2_size.y},
							},
						},
					},
				)

				container(
					ctx,
					"container_3",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_3_size.x},
								{kind = .Fixed, value = data.container_3_size.y},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic --- 
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {

		panel_size := Vec2 {
			data.largest_container_x + data.panel_padding.left + data.panel_padding.right,
			data.panel_padding.top +
			data.panel_padding.bottom +
			data.panel_child_gap * 2 +
			data.container_1_size.y +
			data.container_2_size.y +
			data.container_3_size.y,
		}

		panel_pos := Vec2{0, 0}
		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + data.container_1_size.y + data.panel_child_gap
		c3_pos_y := c2_pos_y + data.container_2_size.y + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = panel_pos,
					size = panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left, c2_pos_y},
							size = data.container_2_size,
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left, c3_pos_y},
							size = data.container_3_size,
						},
					},
				},
			},
		}
		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)

}

@(test)
test_grow_sizing_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Grow_Sizing_Ltr_Context :: struct {
		panel_padding:    Padding,
		panel_child_gap:  f32,
		panel_size:       Vec2,
		container_1_size: Vec2,
		container_3_size: Vec2,
	}

	test_context := Test_Grow_Sizing_Ltr_Context {
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {
						{kind = .Fixed, value = data.panel_size.x},
						{kind = .Fixed, value = data.panel_size.y},
					},
					layout_direction = .Left_To_Right,
					padding = data.panel_padding,
					child_gap = data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Grow_Sizing_Ltr_Context) {
				container(
					ctx,
					"container_1",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_1_size.x},
								{kind = .Fixed, value = data.container_1_size.y},
							},
						},
					},
				)

				container(
					ctx,
					"container_2",
					{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
				)

				container(
					ctx,
					"container_3",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_3_size.x},
								{kind = .Fixed, value = data.container_3_size.y},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Grow_Sizing_Ltr_Context) {
		inner_panel_w := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		inner_panel_h := data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		total_fixed_w := data.container_1_size.x + data.container_3_size.x
		total_gap_w := data.panel_child_gap * 2
		container_2_w := inner_panel_w - total_fixed_w - total_gap_w

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + data.container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + container_2_w + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = {container_2_w, inner_panel_h},
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])

	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_context)
}

@(test)
test_grow_sizing_max_value_ltr :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Data ---
	Test_Data :: struct {
		panel_padding:         Padding,
		panel_child_gap:       f32,
		panel_size:            Vec2,
		container_1_max_value: f32,
		container_2_max_value: f32,
		container_3_size:      Vec2,
	}

	test_data := Test_Data {
		panel_padding = Padding{left = 11, top = 12, right = 13, bottom = 14},
		panel_child_gap = 10,
		panel_size = Vec2{600, 400},
		container_1_max_value = 150,
		container_2_max_value = 50,
		container_3_size = Vec2{150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {
						{kind = .Fixed, value = data.panel_size.x},
						{kind = .Fixed, value = data.panel_size.y},
					},
					layout_direction = .Left_To_Right,
					padding = data.panel_padding,
					child_gap = data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					{layout = {sizing = {{kind = .Grow, max_value = 150}, {kind = .Grow}}}},
				)
				container(
					ctx,
					"container_2",
					{layout = {sizing = {{kind = .Grow, max_value = 50}, {kind = .Grow}}}},
				)
				container(
					ctx,
					"container_3",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_3_size.x},
								{kind = .Fixed, value = data.container_3_size.y},
							},
							layout_direction = .Left_To_Right,
							padding = data.panel_padding,
							child_gap = data.panel_child_gap,
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		container_1_size := Vec2 {
			data.container_1_max_value,
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom,
		}

		container_2_size := Vec2 {
			data.container_2_max_value,
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom,
		}

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + container_1_size.x + data.panel_child_gap
		c3_pos_x := c2_pos_x + container_2_size.x + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = container_1_size,
						},
						{
							id = "container_2",
							pos = {c2_pos_x, data.panel_padding.top},
							size = container_2_size,
						},
						{
							id = "container_3",
							pos = {c3_pos_x, data.panel_padding.top},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_sizing_ttb :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_padding:    Padding,
		panel_child_gap:  f32,
		panel_size:       Vec2,
		container_1_size: Vec2,
		container_3_size: Vec2,
	}

	test_data := Test_Data {
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = {600, 400},
		container_1_size = {100, 100},
		container_3_size = {150, 150},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {
						{kind = .Fixed, value = data.panel_size.x},
						{kind = .Fixed, value = data.panel_size.y},
					},
					layout_direction = .Top_To_Bottom,
					padding = data.panel_padding,
					child_gap = 10,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				container(
					ctx,
					"container_1",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_1_size.x},
								{kind = .Fixed, value = data.container_1_size.y},
							},
						},
					},
				)
				container(
					ctx,
					"container_2",
					{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
				)
				container(
					ctx,
					"container_3",
					{
						layout = {
							sizing = {
								{kind = .Fixed, value = data.container_3_size.x},
								{kind = .Fixed, value = data.container_3_size.y},
							},
						},
					},
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {

		inner_panel_w := data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		inner_panel_h := data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		total_fixed_h := data.container_1_size.y + data.container_3_size.y
		total_gap_h := data.panel_child_gap * 2
		container_2_h := inner_panel_h - total_fixed_h - total_gap_h

		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + data.container_1_size.y + data.panel_child_gap
		c3_pos_y := c2_pos_y + container_2_h + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "container_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = data.container_1_size,
						},
						{
							id = "container_2",
							pos = {data.panel_padding.left, c2_pos_y},
							size = {inner_panel_w, container_2_h},
						},
						{
							id = "container_3",
							pos = {data.panel_padding.left, c3_pos_y},
							size = data.container_3_size,
						},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ltr :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_padding:      Padding,
		panel_child_gap:    f32,
		panel_size:         Vec2,
		text_1_min_width:   f32,
		grow_box_min_width: f32,
		text_2_min_width:   f32,
	}

	test_data := Test_Data {
		panel_padding = {left = 10, top = 10, right = 10, bottom = 10},
		panel_child_gap = 10,
		panel_size = Vec2{300, 100},
		text_1_min_width = 10,
		grow_box_min_width = 5,
		text_2_min_width = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {
						{kind = .Fixed, value = data.panel_size.x},
						{kind = .Fixed, value = data.panel_size.y},
					},
					layout_direction = .Left_To_Right,
					padding = data.panel_padding,
					child_gap = data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				text(ctx, "text_1", "First", min_width = data.text_1_min_width)

				container(
					ctx,
					"grow_box",
					{
						layout = {
							sizing = {
								{kind = .Grow, min_value = data.grow_box_min_width},
								{kind = .Grow},
							},
						},
					},
				)

				text(ctx, "text_2", "Last", min_width = data.text_2_min_width)

			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {

		available_width :=
			data.panel_size.x -
			data.panel_padding.left -
			data.panel_padding.right -
			2 * data.panel_child_gap

		expected_child_width := available_width / 3
		expected_child_height :=
			data.panel_size.y - data.panel_padding.top - data.panel_padding.bottom

		c1_pos_x := data.panel_padding.left
		c2_pos_x := c1_pos_x + expected_child_width + data.panel_child_gap
		c3_pos_x := c2_pos_x + expected_child_width + data.panel_child_gap


		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "text_1",
							pos = {c1_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "grow_box",
							pos = {c2_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "text_2",
							pos = {c3_pos_x, data.panel_padding.top},
							size = {expected_child_width, expected_child_height},
						},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_grow_sizing_with_mixed_elements_reach_equal_size_ttb :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		panel_padding:       Padding,
		panel_child_gap:     f32,
		panel_size:          Vec2,
		text_1_min_height:   f32,
		grow_box_min_height: f32,
		text_2_min_height:   f32,
	}

	test_data := Test_Data {
		panel_padding = {left = 10, top = 11, right = 12, bottom = 13},
		panel_child_gap = 10,
		panel_size = Vec2{100, 100},
		text_1_min_height = 10,
		grow_box_min_height = 5,
		text_2_min_height = 0,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"panel",
			{
				layout = {
					sizing = {
						{kind = .Fixed, value = data.panel_size.x},
						{kind = .Fixed, value = data.panel_size.y},
					},
					layout_direction = .Top_To_Bottom,
					padding = data.panel_padding,
					child_gap = data.panel_child_gap,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				text(ctx, "text_1", "First", min_height = data.text_1_min_height)

				container(
					ctx,
					"grow_box",
					{
						layout = {
							sizing = {
								{kind = .Grow, min_value = data.grow_box_min_height},
								{kind = .Grow},
							},
						},
					},
				)

				text(ctx, "text_2", "Last", min_width = data.text_2_min_height)

			},
		)
	}


	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {

		available_height :=
			data.panel_size.y -
			data.panel_padding.top -
			data.panel_padding.bottom -
			2 * data.panel_child_gap

		expected_child_width :=
			data.panel_size.x - data.panel_padding.left - data.panel_padding.right
		expected_child_height := available_height / 3

		c1_pos_y := data.panel_padding.top
		c2_pos_y := c1_pos_y + expected_child_height + data.panel_child_gap
		c3_pos_y := c2_pos_y + expected_child_height + data.panel_child_gap

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "panel",
					pos = {0, 0},
					size = data.panel_size,
					children = []Expected_Element {
						{
							id = "text_1",
							pos = {data.panel_padding.left, c1_pos_y},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "grow_box",
							pos = {data.panel_padding.left, c2_pos_y},
							size = {expected_child_width, expected_child_height},
						},
						{
							id = "text_2",
							pos = {data.panel_padding.left, c3_pos_y},
							size = {expected_child_width, expected_child_height},
						},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

// TODO(Thomas): Add other tests where we overflow the max sizing within and outside
// of a fit sizing container.
// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_basic_text_element_sizing :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		text_min_width: f32,
		text_max_width: f32,
	}

	test_data := Test_Data {
		text_min_width = 50,
		text_max_width = 100,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"text_fit_wrapper",
			{layout = {sizing = {{kind = .Fit}, {kind = .Fit}}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text",
					"012345",
					min_width = data.text_min_width,
					max_width = data.text_max_width,
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = 6 * MOCK_CHAR_WIDTH
		text_height: f32 = MOCK_LINE_HEIGHT

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = "text", pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_text_element_sizing_with_newlines :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		id:   string,
		text: string,
	}

	test_data := Test_Data {
		id   = "text",
		text = "One\nTwo",
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"text_fit_wrapper",
			{layout = {sizing = {{kind = .Fit}, {kind = .Fit}}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(ctx, data.id, data.text)
			},
		)

	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = 3 * MOCK_CHAR_WIDTH
		text_height: f32 = 2 * MOCK_LINE_HEIGHT

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = data.id, pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}


@(test)
test_text_element_sizing_with_whitespace_overflowing_with_padding :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		container_id:      string,
		container_padding: Padding,
		text_id:           string,
		text:              string,
	}

	test_data := Test_Data {
		container_id = "container",
		container_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
		text_id = "text",
		text = "Button 1",
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			data.container_id,
			{
				layout = {
					sizing = {{kind = .Fixed, value = 60}, {kind = .Fit}},
					padding = data.container_padding,
				},
			},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(ctx, data.text_id, data.text)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		padding := data.container_padding
		container_size := Vec2{60, 2 * MOCK_LINE_HEIGHT + padding.top + padding.bottom}

		// Space for text is size of the text minus paddings
		text_size := Vec2{6 * MOCK_CHAR_WIDTH - padding.left - padding.right, 2 * MOCK_LINE_HEIGHT}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					data.container_id,
					{0, 0},
					container_size,
					{{data.text_id, {padding.left, padding.top}, text_size, {}}},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

// TODO(Thomas): This test has a text_fit_wrapper container
// to make sure that it doesn't have to deal with the root's
// fixed size. I'm not sure if that's exactly what we want.
@(test)
test_basic_text_element_underflow_sizing :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		text_min_width:  f32,
		text_min_height: f32,
	}

	test_data := Test_Data {
		text_min_width  = 50,
		text_min_height = 20,
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {

		container(
			ctx,
			"text_fit_wrapper",
			{layout = {sizing = {{kind = .Fit}, {kind = .Fit}}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {
				text(
					ctx,
					"text",
					"01",
					min_width = data.text_min_width,
					min_height = data.text_min_height,
				)
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = data.text_min_width
		text_height: f32 = data.text_min_height

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{
					id = "text_fit_wrapper",
					pos = {0, 0},
					size = {text_width, text_height},
					children = []Expected_Element {
						{id = "text", pos = {0, 0}, size = {text_width, text_height}},
					},
				},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_iterated_texts_layout :: proc(t: ^testing.T) {
	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		items: [5]string,
	}

	test_data := Test_Data {
		items = {"One", "Two", "Three", "Four", "Five"},
	}

	// --- 2. Define the UI Building Logic ---
	build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
		container(
			ctx,
			"parent",
			{layout = {sizing = {{kind = .Fit}, {kind = .Fit}}}},
			data,
			proc(ctx: ^Context, data: ^Test_Data) {

				for item in data.items {
					text(ctx, item, item)
				}
			},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		expected_elements: [5]Expected_Element
		width_offset: f32 = 0
		for item, idx in data.items {
			width := f32(len(item) * MOCK_CHAR_WIDTH)
			expected_elements[idx] = Expected_Element {
				id   = item,
				pos  = {width_offset, 0},
				size = {width, MOCK_LINE_HEIGHT},
			}

			width_offset += width
		}

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = expected_elements[:],
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}

@(test)
test_basic_container_alignments_ltr :: proc(t: ^testing.T) {

	// --- 1. Define the Test-Specific Context Data ---
	Test_Data :: struct {
		parent_width:     f32,
		parent_height:    f32,
		parent_pos:       Vec2,
		alignment_x:      Alignment_X,
		alignment_y:      Alignment_Y,
		container_width:  f32,
		container_height: f32,
		container_pos:    Vec2,
	}

	generate_test_data :: proc(
		parent_height: f32,
		parent_width: f32,
		container_width: f32,
		container_height: f32,
		alignment_x: Alignment_X,
		alignment_y: Alignment_Y,
	) -> Test_Data {

		container_pos: Vec2
		switch alignment_x {
		case .Left:
			container_pos.x = 0
		case .Center:
			container_pos.x = (parent_width / 2) - (container_width / 2)
		case .Right:
			container_pos.x = parent_width - container_width
		}

		switch alignment_y {
		case .Top:
			container_pos.y = 0
		case .Center:
			container_pos.y = (parent_height / 2) - (container_height / 2)
		case .Bottom:
			container_pos.y = parent_height - container_height
		}

		return Test_Data {
			parent_width = parent_width,
			parent_height = parent_height,
			parent_pos = Vec2{0, 0},
			alignment_x = alignment_x,
			alignment_y = alignment_y,
			container_width = container_width,
			container_height = container_height,
			container_pos = container_pos,
		}
	}

	parent_width: f32 = 100
	parent_height: f32 = 100
	container_width: f32 = 50
	container_height: f32 = 50

	tests_data := []Test_Data {
		// Left-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Top,
		),
		// Center-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Top,
		),
		// Right-Top
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Top,
		),
		// Left-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Center,
		),
		// Center-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Center,
		),
		// Right-Center
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Center,
		),
		// Left-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Left,
			.Bottom,
		),
		// Center-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Center,
			.Bottom,
		),
		// Right-Bottom
		generate_test_data(
			parent_width,
			parent_height,
			container_width,
			container_height,
			.Right,
			.Bottom,
		),
	}


	for &test_data in tests_data {
		// --- 2. Define the UI Building Logic ---
		build_ui_proc :: proc(ctx: ^Context, data: ^Test_Data) {
			container(
				ctx,
				"parent",
				{
					layout = {
						sizing = {
							{kind = .Fixed, value = data.parent_width},
							{kind = .Fixed, value = data.parent_height},
						},
						alignment_x = data.alignment_x,
						alignment_y = data.alignment_y,
					},
				},
				data,
				proc(ctx: ^Context, data: ^Test_Data) {
					container(
						ctx,
						"container",
						{
							layout = {
								sizing = {
									{kind = .Fixed, value = data.container_width},
									{kind = .Fixed, value = data.container_height},
								},
							},
						},
					)
				},
			)
		}

		// --- 3. Define the Verification Logic ---
		verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
			expected_layout_tree := Expected_Element {
				id       = "root",
				children = []Expected_Element {
					{
						id = "parent",
						pos = data.parent_pos,
						size = {data.parent_width, data.parent_height},
						children = []Expected_Element {
							{
								id = "container",
								pos = data.container_pos,
								size = {data.container_width, data.container_height},
							},
						},
					},
				},
			}

			expect_layout(t, root, expected_layout_tree.children[0])
		}

		// --- 4. Run the Test ---
		run_layout_test(t, build_ui_proc, verify_proc, &test_data)
	}
}
