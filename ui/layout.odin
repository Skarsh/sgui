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

Content_None :: struct {
}

Text_Data :: struct {
	config: Text_Element_Config,
	lines:  []Text_Line,
}

Element_Content :: union {
	Content_None,
	Text_Data,
}

Layout_Config :: struct {
	sizing:           [2]Sizing,
	padding:          Padding,
	child_gap:        f32,
	layout_direction: Layout_Direction,
	alignment_x:      Alignment_X,
	alignment_y:      Alignment_Y,
}

Clip_Config :: struct {
	clip_axes: [2]bool,
}

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
	content:   Element_Content,
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

open_element :: proc(ctx: ^Context, id: string, element_config: Element_Config) -> bool {
	element, element_ok := make_element(ctx, id, element_config)
	assert(element_ok)

	element.content = Content_None{}

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

// TODO(Thomas): Having min and max values for width in both Element_Config and Text_Element_Config
// is a source of confusion. At least everything sizing related after opening / creation should use
// the element sizing, but preferably all of this should be set in one place and then make it
// obvious which one to use. Or maybe even impossible to use the wrong one.
open_text_element :: proc(ctx: ^Context, id: string, text_config: Text_Element_Config) -> bool {
	text_metrics := ctx.measure_text_proc(text_config.data, ctx.font_id, ctx.font_user_data)

	width := text_metrics.width
	height := text_metrics.line_height

	min_width := text_config.min_width
	max_width :=
		approx_equal(text_config.max_width, 0, 0.001) ? math.F32_MAX : text_config.max_width

	if width < min_width {
		width = min_width
	} else if width > max_width {
		width = max_width
	}

	min_height := text_config.min_height
	max_height :=
		approx_equal(text_config.max_height, 0, 0.001) ? math.F32_MAX : text_config.max_height

	if height < min_height {
		height = min_height
	} else if height > max_height {
		height = max_height
	}

	element, element_ok := make_element(
		ctx,
		id,
		Element_Config {
			layout = {
				sizing = {
					{kind = .Grow, min_value = min_width, value = width, max_value = max_width},
					{kind = .Grow, min_value = min_height, value = height, max_value = max_height},
				},
				alignment_x = text_config.alignment_x,
				alignment_y = text_config.alignment_y,
			},
		},
	)
	assert(element_ok)
	if !element_ok {
		return false
	}

	element.content = Text_Data {
		config = text_config,
	}

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
	if open_element(ctx, id, config) {
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
	if open_element(ctx, id, config) {
		defer close_element(ctx)
		if body != nil {
			body(ctx, data)
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
			size_kind := child.config.layout.sizing[axis].kind

			if size_kind == .Grow {
				small_array.push(&growables, child)

				// The minimum size is non-negotiable and contributes to the used space.
				// Reset the element's size to its minimum before distribution.
				child.size[axis] = child.min_size[axis]
				remaining_size -= child.size[axis]

			} else {
				// Handles .Fixed and .Fit, which have pre-determined sizes
				remaining_size -= child.size[axis]
			}
		}

		remaining_size -= child_gap
	} else {
		// For secondary axis, directly distribute available space
		for child in element.children {
			size_kind := child.config.layout.sizing[axis].kind
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
			size_kind := child.config.layout.sizing[axis].kind
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

	#partial switch &content in element.content {
	case Text_Data:
		text := content.config.data
		tokens := make([dynamic]Text_Token, allocator)
		tokenize_text(ctx, text, ctx.font_id, &tokens)

		lines := make([dynamic]Text_Line, allocator)
		layout_lines(ctx, text, tokens[:], element.size.x, &lines)

		content.lines = lines[:]
		text_height: f32 = 0
		for line in lines {
			text_height += line.height
		}
		element.size.y = math.clamp(text_height, element.min_size.y, element.max_size.y)
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
	element.position.x = 0
	element.position.y = 0
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
		panel_size = Vec2{140, 100},
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

				text(ctx, "text_1", {data = "First", min_width = data.text_1_min_width})

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

				text(ctx, "text_2", {data = "Last", min_width = data.text_2_min_width})

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

// TODO(Thomas): Add other tests where we overflow the max sizing within and outside
// of a fit sizing container.
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
		text(
			ctx,
			"text",
			{data = "012345", min_width = data.text_min_width, max_width = data.text_max_width},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = 6 * MOCK_CHAR_WIDTH
		text_height: f32 = MOCK_LINE_HEIGHT

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{id = "text", pos = {0, 0}, size = {text_width, text_height}},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}


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
		text(
			ctx,
			"text",
			{data = "01", min_width = data.text_min_width, min_height = data.text_min_height},
		)
	}

	// --- 3. Define the Verification Logic ---
	verify_proc :: proc(t: ^testing.T, root: ^UI_Element, data: ^Test_Data) {
		text_width: f32 = data.text_min_width
		text_height: f32 = data.text_min_height

		expected_layout_tree := Expected_Element {
			id       = "root",
			children = []Expected_Element {
				{id = "text", pos = {0, 0}, size = {text_width, text_height}},
			},
		}

		expect_layout(t, root, expected_layout_tree.children[0])
	}

	// --- 4. Run the Test ---
	run_layout_test(t, build_ui_proc, verify_proc, &test_data)
}
