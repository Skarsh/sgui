package ui

import "core:container/small_array"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"

import base "../base"

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

Layout_Mode :: enum {
	Flow,
	Relative,
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

Shape_Data :: struct {
	kind:      Shape_Kind,
	fill:      base.Fill,
	thickness: f32,
}

Element_Content :: struct {
	text_data:  Text_Data,
	image_data: rawptr,
	shape_data: Shape_Data,
}

Layout_Config :: struct {
	sizing:            [2]Sizing,
	padding:           Padding,
	child_gap:         f32,
	layout_mode:       Layout_Mode,
	layout_direction:  Layout_Direction,
	relative_position: base.Vec2,
	alignment_x:       Alignment_X,
	alignment_y:       Alignment_Y,
	text_padding:      Padding,
	text_alignment_x:  Alignment_X,
	text_alignment_y:  Alignment_Y,
	corner_radius:     f32,
	border_thickness:  f32,
}

Clip_Config :: struct {
	clip_axes: [2]bool,
}

Scroll_Region :: struct {
	offset:       base.Vec2,
	content_size: base.Vec2,
}

// TODO(Thomas): Redundant data between the Element_Config and fields in this struct
// e.g. sizes, etc.
UI_Element :: struct {
	parent:         ^UI_Element,
	id_string:      string,
	position:       base.Vec2,
	min_size:       base.Vec2,
	max_size:       base.Vec2,
	size:           base.Vec2,
	scroll_region:  Scroll_Region,
	config:         Element_Config,
	children:       [dynamic]^UI_Element,
	fill:           base.Fill,
	z_index:        i32,
	hot:            f32,
	active:         f32,
	last_comm:      Comm,
	last_frame_idx: u64,
}

Sizing :: struct {
	kind:      Size_Kind,
	min_value: f32,
	max_value: f32,
	value:     f32,
}

Element_Config :: struct {
	layout:           Layout_Config,
	background_fill:  base.Fill,
	text_fill:        base.Fill,
	border_fill:      base.Fill,
	clip:             Clip_Config,
	capability_flags: Capability_Flags,
	content:          Element_Content,
}

Layout_Options :: struct {
	sizing:            [2]^Sizing,
	padding:           ^Padding,
	child_gap:         ^f32,
	layout_mode:       ^Layout_Mode,
	layout_direction:  ^Layout_Direction,
	relative_position: ^base.Vec2,
	alignment_x:       ^Alignment_X,
	alignment_y:       ^Alignment_Y,
	text_padding:      ^Padding,
	text_alignment_x:  ^Alignment_X,
	text_alignment_y:  ^Alignment_Y,
	corner_radius:     ^f32,
	border_thickness:  ^f32,
}

Config_Options :: struct {
	layout:           Layout_Options,
	background_fill:  ^base.Fill,
	text_fill:        ^base.Fill,
	border_fill:      ^base.Fill,
	clip:             ^Clip_Config,
	capability_flags: ^Capability_Flags,
	content:          Element_Content,
}

Text_Sizing_Mode :: enum {
	// Do not adjust element sizing
	None,
	// Set preferred size to text size, but respect element min/max and allow stretching
	Grow,
	// Force the element size to equal the text size exactly (Strict)
	Fixed,
}

element_equip_text :: proc(
	ctx: ^Context,
	element: ^UI_Element,
	text: string,
	mode: Text_Sizing_Mode = .Grow,
	text_fill: base.Fill = base.Color{255, 255, 255, 255},
) {
	element.config.capability_flags |= {.Text}

	if element.config.text_fill == nil {
		element.config.text_fill = text_fill
	}

	element.config.content.text_data = Text_Data {
		text = text,
	}

	if mode == .None {
		return
	}

	largest_line_width, text_height, _ := measure_text_content(
		ctx,
		text,
		math.F32_MAX,
		context.temp_allocator,
	)
	defer free_all(context.temp_allocator)

	text_padding := element.config.layout.text_padding
	content_width := largest_line_width + text_padding.left + text_padding.right
	content_height := text_height + text_padding.top + text_padding.bottom

	target_width: f32
	target_height: f32

	min_width := element.min_size.x
	max_width := element.max_size.x

	sizing_kind_x: Size_Kind

	switch mode {

	case .Fixed:
		// The element must be exactly the size of the text.
		// We override min and max to ensure no resizing happens.
		target_width = content_width
		min_width = content_width
		max_width = content_width
		sizing_kind_x = .Fixed
	case .Grow:
		// The preferred size is the text size, but we clamp
		// it to the element's existing limits and allow it to grow.
		if content_width < min_width {
			target_width = min_width
		} else if content_width > max_width {
			target_width = max_width
		} else {
			target_width = content_width
		}
		sizing_kind_x = .Grow
	case .None:
		// Unreachable due to early return, but good for completeness
		return
	}


	min_height := element.min_size.y
	max_height := element.max_size.y

	if content_height < min_height {
		target_height = min_height
	} else if content_height > max_height {
		target_height = max_height
	} else {
		target_height = content_height
	}

	element.size.x = target_width
	element.size.y = target_height

	element.config.layout.sizing.x = {
		kind      = sizing_kind_x,
		min_value = min_width,
		value     = target_width,
		max_value = max_width,
	}

	element.config.layout.sizing.y = {
		kind      = .Grow,
		min_value = min_height,
		value     = target_height,
		max_value = max_height,
	}
}

element_equip_shape :: proc(element: ^UI_Element, shape_data: Shape_Data) {
	element.config.capability_flags |= {.Shape}
	element.config.content.shape_data = shape_data
}

calc_child_gap := #force_inline proc(element: UI_Element) -> f32 {
	if len(element.children) == 0 {
		return 0
	} else {
		return f32(len(element.children) - 1) * element.config.layout.child_gap
	}
}

calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.config.layout.padding
	padding_sum := axis == .X ? (padding.left + padding.right) : (padding.top + padding.bottom)

	content_size: f32

	if is_main_axis(element^, axis) {
		// Main Axis: Accumulate size of all children plus gaps
		for child in element.children {
			content_size += child.size[axis]
		}
		content_size += calc_child_gap(element^)
	} else {
		// Cross Axis: The size is determined by the largest child
		for child in element.children {
			content_size = max(content_size, child.size[axis])
		}
	}

	// Add padding
	total_size := content_size + padding_sum

	return math.clamp(total_size, element.min_size[axis], element.max_size[axis])
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent
	}
}

open_element :: proc(
	ctx: ^Context,
	id: string,
	opts: Config_Options = {},
	default_opts: Config_Options = {},
) -> (
	^UI_Element,
	bool,
) {
	final_config := Element_Config{}

	final_config.layout.sizing[Axis2.X] = resolve_value(
		opts.layout.sizing[Axis2.X],
		&ctx.sizing_x_stack,
		resolve_default(default_opts.layout.sizing[Axis2.X]),
	)

	final_config.layout.sizing[Axis2.Y] = resolve_value(
		opts.layout.sizing[Axis2.Y],
		&ctx.sizing_y_stack,
		resolve_default(default_opts.layout.sizing[Axis2.Y]),
	)

	final_config.layout.padding = resolve_value(
		opts.layout.padding,
		&ctx.padding_stack,
		resolve_default(default_opts.layout.padding),
	)

	final_config.layout.child_gap = resolve_value(
		opts.layout.child_gap,
		&ctx.child_gap_stack,
		resolve_default(default_opts.layout.child_gap),
	)

	final_config.layout.layout_mode = resolve_value(
		opts.layout.layout_mode,
		&ctx.layout_mode_stack,
		resolve_default(default_opts.layout.layout_mode),
	)

	final_config.layout.layout_direction = resolve_value(
		opts.layout.layout_direction,
		&ctx.layout_direction_stack,
		resolve_default(default_opts.layout.layout_direction),
	)

	final_config.layout.relative_position = resolve_value(
		opts.layout.relative_position,
		&ctx.relative_position_stack,
		resolve_default(default_opts.layout.relative_position),
	)

	final_config.layout.alignment_x = resolve_value(
		opts.layout.alignment_x,
		&ctx.alignment_x_stack,
		resolve_default(default_opts.layout.alignment_x),
	)

	final_config.layout.alignment_y = resolve_value(
		opts.layout.alignment_y,
		&ctx.alignment_y_stack,
		resolve_default(default_opts.layout.alignment_y),
	)

	final_config.layout.text_padding = resolve_value(
		opts.layout.text_padding,
		&ctx.text_padding_stack,
		resolve_default(default_opts.layout.text_padding),
	)

	final_config.layout.text_alignment_x = resolve_value(
		opts.layout.text_alignment_x,
		&ctx.text_alignment_x_stack,
		resolve_default(default_opts.layout.text_alignment_x),
	)

	final_config.layout.text_alignment_y = resolve_value(
		opts.layout.text_alignment_y,
		&ctx.text_alignment_y_stack,
		resolve_default(default_opts.layout.text_alignment_y),
	)

	final_config.layout.corner_radius = resolve_value(
		opts.layout.corner_radius,
		&ctx.corner_radius_stack,
		resolve_default(default_opts.layout.corner_radius),
	)

	final_config.layout.border_thickness = resolve_value(
		opts.layout.border_thickness,
		&ctx.border_thickness_stack,
		resolve_default(default_opts.layout.border_thickness),
	)

	final_config.background_fill = resolve_value(
		opts.background_fill,
		&ctx.background_fill_stack,
		resolve_default(default_opts.background_fill),
	)

	final_config.text_fill = resolve_value(
		opts.text_fill,
		&ctx.text_fill_stack,
		resolve_default(default_opts.text_fill),
	)

	final_config.border_fill = resolve_value(
		opts.border_fill,
		&ctx.border_fill_stack,
		resolve_default(default_opts.border_fill),
	)

	final_config.clip = resolve_value(
		opts.clip,
		&ctx.clip_stack,
		resolve_default(default_opts.clip),
	)

	// Capability flags are hanled differently by being additive.
	// TODO(Thomas): Should the user specified flags completely override, e.g.
	// not OR but set directly?

	if default_opts.capability_flags != nil {
		final_config.capability_flags |= default_opts.capability_flags^
	}

	if stack_flags, stack_flags_ok := peek(&ctx.capability_flags_stack); stack_flags_ok {
		final_config.capability_flags |= stack_flags
	}

	if opts.capability_flags != nil {
		final_config.capability_flags |= opts.capability_flags^
	}

	// Content is a special case too
	final_config.content = opts.content

	element, element_ok := make_element(ctx, id, final_config)
	assert(element_ok)

	if push(&ctx.element_stack, element) {
		element.z_index = ctx.element_stack.top
	} else {
		return nil, false
	}
	ctx.current_parent = element
	return element, true
}

begin_container :: proc {
	begin_container_no_config,
	begin_container_with_config,
}

begin_container_no_config :: proc(ctx: ^Context, id: string) -> bool {
	_, open_ok := open_element(ctx, id)
	assert(open_ok)
	return open_ok
}

begin_container_with_config :: proc(ctx: ^Context, id: string, opts: Config_Options) -> bool {
	_, open_ok := open_element(ctx, id, opts)
	assert(open_ok)
	return open_ok
}

end_container :: proc(ctx: ^Context) {
	close_element(ctx)
}

container :: proc {
	container_data,
	container_data_no_config,
	container_empty,
	container_empty_no_config,
}

container_empty_no_config :: proc(
	ctx: ^Context,
	id: string,
	empty_body_proc: proc(ctx: ^Context) = nil,
) {
	_, open_ok := open_element(ctx, id)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if empty_body_proc != nil {
			empty_body_proc(ctx)
		}
	}
}

container_empty :: proc(
	ctx: ^Context,
	id: string,
	opts: Config_Options = Config_Options{},
	empty_body_proc: proc(ctx: ^Context) = nil,
) {
	_, open_ok := open_element(ctx, id, opts)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if empty_body_proc != nil {
			empty_body_proc(ctx)
		}
	}
}


container_data_no_config :: proc(
	ctx: ^Context,
	id: string,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) {
	_, open_ok := open_element(ctx, id)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if body != nil {
			body(ctx, data)
		}
	}
}


container_data :: proc(
	ctx: ^Context,
	id: string,
	opts: Config_Options = Config_Options{},
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) {
	_, open_ok := open_element(ctx, id, opts)
	assert(open_ok)
	if open_ok {
		defer close_element(ctx)
		if body != nil {
			body(ctx, data)
		}
	}
}

fit_size_axis :: proc(element: ^UI_Element, axis: Axis2) {
	if element.config.layout.layout_mode != .Flow {
		return
	}

	for child in element.children {
		fit_size_axis(child, axis)
	}

	if element.config.layout.sizing[axis].kind == .Fit {
		calc_element_fit_size_for_axis(element, axis)
	}
}

// TODO(Thomas): The check whether parent sizing kind != .Fixed might not
// be entirely correct. Maybe this will be changed when we start looking into
// overflowing for scrolling etc.
update_parent_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent

	if axis == .X &&
	   parent.config.layout.layout_direction == .Left_To_Right &&
	   parent.config.layout.sizing[axis].kind != .Fixed {
		parent.size.x += element.size.x
		parent.min_size.x += element.min_size.x
		parent.size.y = max(element.size.y, parent.size.y)
		parent.min_size.y = max(element.min_size.y, parent.min_size.y)

	} else if axis == .Y &&
	   parent.config.layout.layout_direction == .Top_To_Bottom &&
	   parent.config.layout.sizing[axis].kind != .Fixed {
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

is_main_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_main_axis :=
		(axis == .X && element.config.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.config.layout.layout_direction == .Top_To_Bottom)

	return is_main_axis
}

get_main_axis :: #force_inline proc(layout_direction: Layout_Direction) -> Axis2 {
	if layout_direction == .Left_To_Right {
		return .X
	} else {
		return .Y
	}
}

get_cross_axis :: #force_inline proc(layout_direction: Layout_Direction) -> Axis2 {
	if layout_direction == .Left_To_Right {
		return .Y
	} else {
		return .X
	}
}

size_children_on_cross_axis :: proc(element: ^UI_Element, axis: Axis2) {
	if element == nil {
		return
	}

	if element.config.layout.sizing[axis].kind == .Fit && !is_main_axis(element^, axis) {
		content_size_on_axis := calc_remaining_size(element^, axis)
		for child in element.children {
			child_sizing_kind := child.config.layout.sizing[axis].kind
			if child_sizing_kind != .Fixed && child_sizing_kind != .Percentage_Of_Parent {
				child.size[axis] = clamp(
					content_size_on_axis,
					child.min_size[axis],
					child.max_size[axis],
				)
			}
		}
	}

	for child in element.children {
		size_children_on_cross_axis(child, axis)
	}
}

@(private)
RESIZE_ITER_MAX :: 32
// Combined grow and shrink size procedure
resolve_grow_sizes_for_children :: proc(element: ^UI_Element, axis: Axis2) {
	if element.config.layout.layout_mode != .Flow {
		return
	}
	// NOTE(Thomas): The reason I went for using a Small_Array here instead
	// of just a normal [dynamic]^UI_Element array is because dynamic arrays
	// can have issues with arena allocators if growing, which would be the case
	// if using contex.temp_allocator. So I decided to just go for Small_Array until
	// I have figured more on how I want to do this. swapping out for Small_Array was very
	// simple, and shouldn't be a problem to go back if we want to use something like a
	// virtual static arena ourselves to ensure the dynamic array stays in place.
	resizables := small_array.Small_Array(1024, ^UI_Element){}
	primary_axis := is_main_axis(element^, axis)

	if primary_axis {

		// Constraints pass
		used_space: f32 = 0
		padding := element.config.layout.padding
		padding_sum := axis == .X ? padding.left + padding.right : padding.top + padding.bottom
		used_space += padding_sum
		for child in element.children {
			size_kind := child.config.layout.sizing[axis].kind
			if size_kind == .Grow {
				child.size[axis] = clamp(
					child.size[axis],
					child.min_size[axis],
					child.max_size[axis],
				)
			}
			used_space += child.size[axis]
		}
		child_gap := calc_child_gap(element^)
		used_space += child_gap

		// Calculate delta and filter resizables
		delta_size := element.size[axis] - used_space

		for child in element.children {
			sizing_kind := child.config.layout.sizing[axis].kind
			if sizing_kind == .Grow {
				if (delta_size > 0 && child.size[axis] < child.max_size[axis]) ||
				   (delta_size < 0 && child.size[axis] > child.min_size[axis]) {
					small_array.push(&resizables, child)
				}
			}
		}

		// TODO(Thomas): Pretty sure this can be simplified
		// Distribution pass
		resize_iter := 0
		for !base.approx_equal(delta_size, 0, EPSILON) && len(small_array.slice(&resizables)) > 0 {
			assert(resize_iter < RESIZE_ITER_MAX)
			resize_iter += 1

			is_growing := delta_size > 0

			size_to_distribute := delta_size
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
					delta_size / f32(len(small_array.slice(&resizables))),
				)

				// NOTE(Thomas): We iterate in reverse order to ensure that the idx
				// after one removal will be valid.
				#reverse for child, idx in small_array.slice(&resizables) {
					prev_size := child.size[axis]
					next_size := child.size[axis]
					child_max_size := child.max_size[axis]
					if base.approx_equal(next_size, smallest, EPSILON) {
						next_size += size_to_distribute
						child.size[axis] = next_size
						if next_size >= child_max_size {
							next_size = child_max_size
							child.size[axis] = next_size
							small_array.unordered_remove(&resizables, idx)
						}
						delta_size -= (next_size - prev_size)
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
					delta_size / f32(len(small_array.slice(&resizables))),
				)

				#reverse for child, idx in small_array.slice(&resizables) {
					prev_size := child.size[axis]
					next_size := child.size[axis]
					child_min_size := child.min_size[axis]
					if base.approx_equal(next_size, largest, EPSILON) {
						next_size += size_to_distribute
						child.size[axis] = next_size

						if next_size <= child_min_size {
							next_size = child_min_size
							child.size[axis] = next_size
							small_array.unordered_remove(&resizables, idx)
						}
						delta_size -= (next_size - prev_size)
					}
				}
			}
		}

	} else {
		remaining_size := calc_remaining_size(element^, axis)
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
				new_size := child.size[axis] + (remaining_size - child.size[axis])
				// Restricting the child size to be within it's min and max size
				child.size[axis] = clamp(new_size, child.min_size[axis], child.max_size[axis])
			}
		}
	}
}

@(private)
resolve_percentage_sizes_for_children :: proc(parent: ^UI_Element, axis: Axis2) {
	parent_padding := parent.config.layout.padding
	parent_content_width := parent.size.x - parent_padding.left - parent_padding.right
	parent_content_height := parent.size.y - parent_padding.top - parent_padding.bottom

	parent_content_size := axis == .X ? parent_content_width : parent_content_height

	for child in parent.children {
		sizing_info := child.config.layout.sizing[axis]
		if sizing_info.kind == .Percentage_Of_Parent {
			percentage := clamp(sizing_info.value, 0.0, 1.0)
			child.size[axis] = parent_content_size * percentage
		}
	}
}

resolve_dependent_sizes_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	if element == nil {
		return
	}

	resolve_percentage_sizes_for_children(element, axis)
	resolve_grow_sizes_for_children(element, axis)

	for child in element.children {
		resolve_dependent_sizes_for_axis(child, axis)
	}
}

wrap_text :: proc(ctx: ^Context, element: ^UI_Element, allocator: mem.Allocator) {
	if .Text in element.config.capability_flags {
		text_padding := element.config.layout.text_padding
		text := element.config.content.text_data.text

		available_width := element.size.x - text_padding.left - text_padding.right
		_, h, lines := measure_text_content(ctx, text, available_width, allocator)

		element.config.content.text_data.lines = lines[:]
		if element.config.layout.sizing.y.kind == .Grow {
			final_height := h + text_padding.top + text_padding.bottom
			element.size.y = math.clamp(final_height, element.min_size.y, element.max_size.y)
		}
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

	set_element_size :: proc(element: ^UI_Element, config: Element_Config) {
		element.size.x = config.layout.sizing.x.value
		element.size.y = config.layout.sizing.y.value

		min_x := config.layout.sizing.x.min_value
		min_y := config.layout.sizing.y.min_value

		element.min_size.x = min_x > 0 ? min_x : 0
		element.min_size.y = min_y > 0 ? min_y : 0

		// NOTE(Thomas): A max value of 0 doesn't make sense, so we assume that
		// the user wants it to just fit whatever, so we set it to f32 max value
		if base.approx_equal(config.layout.sizing.x.max_value, 0, 0.001) {
			element.max_size.x = math.F32_MAX
		} else {
			element.max_size.x = config.layout.sizing.x.max_value
		}

		if base.approx_equal(config.layout.sizing.y.max_value, 0, 0.001) {
			element.max_size.y = math.F32_MAX
		} else {
			element.max_size.y = config.layout.sizing.y.max_value
		}
	}

	key := ui_key_hash(id)

	// TODO(Thomas): This is almost completely duplicate from the cached variant.
	// Should be able to do something common here or move out into procedure.
	if key == ui_key_null() {
		element: ^UI_Element
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.frame_allocator)
		assert(err == .None)
		if err != .None {
			log.error("failed to allocate UI_Element")
			return nil, false
		}

		// TODO(Thomas): @Perf Review whether cloning the id string is the right choice here.
		// The alternative is to put the responsibility of ensuring the lifetime of the string
		// is valid over onto the user?? The id string is really unly used to calculuate the hash
		// so keeping it alive in the element is mostly for debugging purposes.
		str_clone_err: mem.Allocator_Error
		element.id_string, str_clone_err = strings.clone(id, ctx.frame_allocator)
		assert(str_clone_err == .None)
		if str_clone_err != .None {
			log.error("failed to allocate memory for cloning id string")
			return nil, false
		}
		element.children = make([dynamic]^UI_Element, ctx.frame_allocator)

		set_element_size(element, element_config)

		element.parent = ctx.current_parent
		clear_dynamic_array(&element.children)
		if element.parent != nil {
			append(&element.parent.children, element)
		}

		// TODO(Thomas): Prune which of these fields actually has to be set every frame
		// or which can be cached.
		// We need to set this fields every frame
		// TODO(Thomas): Every field that is set from the config here is essentially
		// redundant. We should probably just set the config and then use that for further
		// calculations?
		element.last_frame_idx = ctx.frame_idx
		element.fill = element_config.background_fill
		element.config = element_config

		return element, true
	}

	element, found := ctx.element_cache[key]

	if !found {
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.persistent_allocator)
		assert(err == .None)
		if err != .None {
			log.error("failed to allocate UI_Element")
			return nil, false
		}

		// TODO(Thomas): @Perf Review whether cloning the id string is the right choice here.
		// The alternative is to put the responsibility of ensuring the lifetime of the string
		// is valid over onto the user?? The id string is really unly used to calculuate the hash
		// so keeping it alive in the element is mostly for debugging purposes.
		str_clone_err: mem.Allocator_Error
		element.id_string, str_clone_err = strings.clone(id, ctx.persistent_allocator)
		assert(str_clone_err == .None)
		if str_clone_err != .None {
			log.error("failed to allocate memory for cloning id string")
			return nil, false
		}
		element.children = make([dynamic]^UI_Element, ctx.persistent_allocator)

		set_element_size(element, element_config)

		ctx.element_cache[key] = element
	}

	element.parent = ctx.current_parent
	clear_dynamic_array(&element.children)
	if element.parent != nil {
		append(&element.parent.children, element)
	}

	// TODO(Thomas): Prune which of these fields actually has to be set every frame
	// or which can be cached.
	// We need to set this fields every frame
	// TODO(Thomas): Every field that is set from the config here is essentially
	// redundant. We should probably just set the config and then use that for further
	// calculations?
	element.last_frame_idx = ctx.frame_idx
	element.fill = element_config.background_fill
	element.config = element_config

	return element, true
}

@(private)
get_alignment_factor_x :: #force_inline proc(align: Alignment_X) -> f32 {
	factor: f32 = 0
	switch align {
	case .Left:
		factor = 0.0
	case .Center:
		factor = 0.5
	case .Right:
		factor = 1.0
	}
	return factor
}

@(private)
get_alignment_factor_y :: #force_inline proc(align: Alignment_Y) -> f32 {
	factor: f32 = 0
	switch align {
	case .Top:
		factor = 0.0
	case .Center:
		factor = 0.5
	case .Bottom:
		factor = 1.0
	}
	return factor
}

@(private)
get_alignment_factors :: #force_inline proc(
	align_x: Alignment_X,
	align_y: Alignment_Y,
) -> base.Vec2 {
	factor_x := get_alignment_factor_x(align_x)
	factor_y := get_alignment_factor_y(align_y)
	return base.Vec2{factor_x, factor_y}
}

// TODO(Thomas): Cleanup and simplify. I don't like having to do the .Scrollable capability flag check if we
// don't really have to.
calculate_positions_and_alignment :: proc(parent: ^UI_Element) {
	if parent == nil {
		return
	}

	parent.scroll_region.content_size = {}

	if parent.config.layout.layout_mode == .Flow {

		dir := parent.config.layout.layout_direction
		padding := parent.config.layout.padding

		main_axis := get_main_axis(dir)
		cross_axis := get_cross_axis(dir)

		padding_start_main := main_axis == .X ? padding.left : padding.top
		padding_end_main := main_axis == .X ? padding.right : padding.bottom

		padding_start_cross := cross_axis == .X ? padding.left : padding.top
		padding_end_cross := cross_axis == .X ? padding.right : padding.bottom

		content_start_main := parent.position[main_axis] + padding_start_main
		content_start_cross := parent.position[cross_axis] + padding_start_cross

		content_size_main := parent.size[main_axis] - padding_start_main - padding_end_main
		content_size_cross := parent.size[cross_axis] - padding_start_cross - padding_end_cross

		total_children_main_size: f32
		max_children_cross_size: f32
		for child in parent.children {
			total_children_main_size += child.size[main_axis]
			max_children_cross_size = max(max_children_cross_size, child.size[cross_axis])
		}

		gap := calc_child_gap(parent^)

		parent.scroll_region.content_size[main_axis] = total_children_main_size + gap
		parent.scroll_region.content_size[cross_axis] = max_children_cross_size

		// Calculate Main axis start position
		main_align_factor: f32
		if main_axis == .X {
			main_align_factor = get_alignment_factor_x(parent.config.layout.alignment_x)
		} else {
			main_align_factor = get_alignment_factor_y(parent.config.layout.alignment_y)
		}

		remaining_space_main := content_size_main - total_children_main_size - gap
		current_pos_main := content_start_main + (remaining_space_main * main_align_factor)

		// NOTE(Thomas): Clamping the scroll offsets. It is important that this happens before
		// the scroll offsets are used to calculate the positions.
		max_offset_main: f32
		max_offset_cross: f32
		if .Scrollable in parent.config.capability_flags {
			max_offset_main = parent.scroll_region.content_size[main_axis] - content_size_main
			parent.scroll_region.offset[main_axis] = clamp(
				parent.scroll_region.offset[main_axis],
				0,
				max_offset_main,
			)

			max_offset_cross = parent.scroll_region.content_size[cross_axis] - content_size_cross
			parent.scroll_region.offset[cross_axis] = clamp(
				parent.scroll_region.offset[cross_axis],
				0,
				max_offset_cross,
			)
		}

		// Place the children
		for child in parent.children {

			// Main Axis
			child.position[main_axis] = current_pos_main - parent.scroll_region.offset[main_axis]
			current_pos_main += child.size[main_axis] + parent.config.layout.child_gap

			// Cross Axis
			cross_align_factor: f32
			if cross_axis == .X {
				cross_align_factor = get_alignment_factor_x(parent.config.layout.alignment_x)
			} else {
				cross_align_factor = get_alignment_factor_y(parent.config.layout.alignment_y)
			}

			remaining_space_cross := content_size_cross - child.size[cross_axis]
			child.position[cross_axis] =
				content_start_cross +
				(remaining_space_cross * cross_align_factor) -
				parent.scroll_region.offset[cross_axis]
		}

	} else {
		// Relative Layout_Mode
		// TODO(Thomas): Scrolling - I assume it makes sense here?

		padding := parent.config.layout.padding

		content_pos := base.Vec2{parent.position.x + padding.left, parent.position.y + padding.top}

		content_size := base.Vec2 {
			parent.size.x - padding.left - padding.right,
			parent.size.y - padding.top - padding.bottom,
		}

		for child in parent.children {
			factor := get_alignment_factors(
				child.config.layout.alignment_x,
				child.config.layout.alignment_y,
			)

			child.position =
				content_pos + (content_size * factor) + child.config.layout.relative_position
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
	expected_size: base.Vec2,
	epsilon: f32 = EPSILON,
) -> bool {
	return base.approx_equal_vec2(element.size, expected_size, epsilon)
}

// Helper to verify element position
compare_element_position :: proc(
	element: UI_Element,
	expected_pos: base.Vec2,
	epsilon: f32 = EPSILON,
) -> bool {
	return base.approx_equal_vec2(element.position, expected_pos, epsilon)
}

// Helper to find an element in element hierarchy by id string
find_element_by_id :: proc(ctx: ^Context, id: string) -> ^UI_Element {
	key := ui_key_hash(id)
	if element, ok := ctx.element_cache[key]; ok {
		return element
	}
	return nil
}


// Finds and returns a pointer to the element with matchin id string in current hierarchy.
find_element_in_hierarchy :: proc(root: ^UI_Element, id: string) -> ^UI_Element {
	if root == nil {
		return nil
	}

	if root.id_string == id {
		return root
	}

	for child in root.children {
		result := find_element_in_hierarchy(child, id)

		if result != nil {
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

	log.infof("id: %v, size: %v", root.id_string, root.size)

	for child in root.children {
		print_element_hierarchy(child)
	}
}
