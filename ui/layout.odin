package ui

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
	offset:        base.Vec2,
	target_offset: base.Vec2,
	max_offset:    base.Vec2,
	content_size:  base.Vec2,
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
	content_size := base.Vec2 {
		largest_line_width + text_padding.left + text_padding.right,
		text_height + text_padding.top + text_padding.bottom,
	}

	sizing_kind_x := Size_Kind.Grow
	target_size := content_size

	if mode == .Fixed {
		// Override element oncstraints to match exactly
		element.min_size.x = content_size.x
		element.max_size.x = content_size.x
		sizing_kind_x = .Fixed
	} else {
		// Clamp content size to element's existing constraints
		target_size.x = math.clamp(content_size.x, element.min_size.x, element.max_size.x)
	}

	// Height is always treated as .Grow
	target_size.y = math.clamp(content_size.y, element.min_size.y, element.max_size.y)

	element.size = target_size

	element.config.layout.sizing.x = {
		kind      = sizing_kind_x,
		min_value = element.min_size.x,
		value     = target_size.x,
		max_value = element.max_size.x,
	}

	element.config.layout.sizing.y = {
		kind      = .Grow,
		min_value = element.min_size.y,
		value     = target_size.y,
		max_value = element.max_size.y,
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


// TODO(Thomas): This can be simplified further by combining into a Vec2, but not sure if that
// helps much since the layout algorithm needs to update per axis anyway.
calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	padding := element.config.layout.padding
	padding_sum := get_padding_sum_for_axis(padding, axis)

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
	// Clamp
	// TODO(Thomas): Add test that catches if this clamp doesn't happen.
	total_size = math.clamp(total_size, element.min_size[axis], element.max_size[axis])
	return total_size
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

begin_container :: proc(ctx: ^Context, id: string, opts: Config_Options = {}) -> bool {
	_, open_ok := open_element(ctx, id, opts)
	assert(open_ok)
	return open_ok
}

end_container :: proc(ctx: ^Context) {
	close_element(ctx)
}

container :: proc {
	container_basic,
	container_styled,
	container_data,
	container_data_styled,
}

container_basic :: proc(ctx: ^Context, id: string, body: proc(ctx: ^Context) = nil) {
	if begin_container(ctx, id) {
		if body != nil {
			body(ctx)
		}
		end_container(ctx)
	}
}

container_styled :: proc(
	ctx: ^Context,
	id: string,
	opts: Config_Options,
	body: proc(ctx: ^Context) = nil,
) {
	if begin_container(ctx, id, opts) {
		if body != nil {
			body(ctx)
		}
		end_container(ctx)
	}
}

container_data :: proc(
	ctx: ^Context,
	id: string,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) {
	if begin_container(ctx, id) {
		if body != nil {
			body(ctx, data)
		}
		end_container(ctx)
	}
}

container_data_styled :: proc(
	ctx: ^Context,
	id: string,
	opts: Config_Options,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) {
	if begin_container(ctx, id, opts) {
		if body != nil {
			body(ctx, data)
		}
		end_container(ctx)
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

update_parent_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent

	if parent == nil {
		return
	}

	if parent.config.layout.sizing[axis].kind == .Fixed {
		return
	}

	if is_main_axis(parent^, axis) {
		// Accumulate sum
		parent.size[axis] += element.size[axis]
		parent.min_size[axis] += element.min_size[axis]
	} else {
		// Expand to largest child
		parent.size[axis] = max(element.size[axis], parent.size[axis])
		parent.min_size[axis] = max(element.min_size[axis], parent.min_size[axis])
	}
}

calc_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	element.size[axis] = calculate_element_size_for_axis(element, axis)

	if element.parent != nil {
		update_parent_element_fit_size_for_axis(element, axis)
	}
}

// TODO(Thomas): Can be simplified further by returning a Vec2 of the content size instead of just the one axis
calc_remaining_size :: #force_inline proc(element: UI_Element, axis: Axis2) -> f32 {
	padding := element.config.layout.padding
	padding_sum := get_padding_sum_for_axis(padding, axis)

	remaining_size := element.size[axis] - padding_sum
	return remaining_size
}

is_main_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_main_axis :=
		(axis == .X && element.config.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.config.layout.layout_direction == .Top_To_Bottom)

	return is_main_axis
}

get_main_and_cross_axis :: proc(
	layout_direction: Layout_Direction,
) -> (
	main_axis: Axis2,
	cross_axis: Axis2,
) {
	if layout_direction == .Left_To_Right {
		main_axis = .X
		cross_axis = .Y
	} else {
		main_axis = .Y
		cross_axis = .X
	}
	return main_axis, cross_axis
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

calculate_size_to_distribute :: proc(
	is_growing: bool,
	resizables: []^UI_Element,
	axis: Axis2,
) -> (
	dist: f32,
	target: f32,
) {
	if len(resizables) == 0 {
		return 0, 0
	}

	sign: f32 = is_growing ? 1 : -1

	first: f32 = resizables[0].size[axis] * sign
	second: f32 = math.INF_F32

	for child in resizables {
		val := child.size[axis] * sign
		// NOTE(Thomas): We're skipping children that has the same size as first, this is important to make sure
		// to ensure that first and second doesn't become equal, causing all sorts of nastyness later.
		if val < first {
			second = first
			first = val
		} else if val > first {
			second = min(second, val)
		}
	}

	// Share needs to have the sign that matches whether it's growing or not.
	// When it's not growing, i.e. shrinking, the share needs to be negative.
	dist = (second - first) * sign
	target = first * sign
	return
}


// Combined grow and shrink size procedure
@(private)
RESIZE_ITER_MAX :: 32
resolve_grow_sizes_for_children :: proc(element: ^UI_Element, axis: Axis2) {
	if element.config.layout.layout_mode != .Flow {
		return
	}
	resizables := make([dynamic]^UI_Element, context.temp_allocator)
	defer free_all(context.temp_allocator)
	main_axis := is_main_axis(element^, axis)

	if main_axis {

		// Constraints pass
		used_space: f32 = 0
		padding := element.config.layout.padding
		padding_sum := get_padding_sum_for_axis(padding, axis)
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
					append(&resizables, child)
				}
			}
		}

		// Distribution pass
		resize_iter := 0
		for !base.approx_equal(delta_size, 0, EPSILON) && len(resizables) > 0 {
			assert(resize_iter < RESIZE_ITER_MAX)
			resize_iter += 1

			is_growing := delta_size > 0

			dist, target := calculate_size_to_distribute(is_growing, resizables[:], axis)

			share := delta_size / f32(len(resizables))
			step_amount := dist
			if abs(share) < abs(dist) {
				step_amount = share
			}

			#reverse for child, idx in resizables {
				// Only process children close to the target value
				if base.approx_equal(child.size[axis], target, EPSILON) {
					prev_size := child.size[axis]
					potential_size := prev_size + step_amount

					next_size := clamp(potential_size, child.min_size[axis], child.max_size[axis])

					child.size[axis] = next_size
					delta_size -= (next_size - prev_size)

					// If the size was clamped (didn't reach potential), we hit a limit.
					// Remove this child from the pool so we don't try to resize it again
					if !base.approx_equal(next_size, potential_size, EPSILON) {
						unordered_remove(&resizables, idx)
					}
				}
			}
		}

	} else {
		remaining_size := calc_remaining_size(element^, axis)
		// Cross axis
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
	parent_content_available_size := get_available_size(parent.size, parent_padding)

	for child in parent.children {
		sizing_info := child.config.layout.sizing[axis]
		if sizing_info.kind == .Percentage_Of_Parent {
			percentage := clamp(sizing_info.value, 0.0, 1.0)
			child.size[axis] = parent_content_available_size[axis] * percentage
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

		available_size := get_available_size(element.size, text_padding)
		_, h, lines := measure_text_content(ctx, text, available_size.x, allocator)

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

	update_element_configuration :: proc(element: ^UI_Element, config: Element_Config, idx: u64) {
		element.last_frame_idx = idx
		element.config = config
		element.fill = config.background_fill

		min_x := config.layout.sizing.x.min_value
		min_y := config.layout.sizing.y.min_value

		element.min_size.x = max(min_x, 0)
		element.min_size.y = max(min_y, 0)

		element.max_size.x =
			base.approx_equal(config.layout.sizing.x.max_value, 0, 0.001) ? math.F32_MAX : config.layout.sizing.x.max_value

		element.max_size.y =
			base.approx_equal(config.layout.sizing.y.max_value, 0, 0.001) ? math.F32_MAX : config.layout.sizing.y.max_value

		if config.layout.sizing.x.kind == .Fixed {
			element.size.x = config.layout.sizing.x.value
		}

		if config.layout.sizing.y.kind == .Fixed {
			element.size.y = config.layout.sizing.y.value
		}
	}


	key := ui_key_hash(id)
	element: ^UI_Element

	if key == ui_key_null() {
		// Non-cached / Temporary Element
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

	} else {
		// Cached Element
		found := false
		element, found = ctx.element_cache[key]

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
			ctx.element_cache[key] = element
		}
	}

	update_element_configuration(element, element_config, ctx.frame_idx)

	element.parent = ctx.current_parent
	clear_dynamic_array(&element.children)
	if element.parent != nil {
		append(&element.parent.children, element)
	}

	return element, true
}

@(private)
get_alignment_factor :: #force_inline proc(align: $E) -> f32 {
	// NOTE(Thomas): This works because Alignment_X and Alignment_Y are both
	// representing the positions (Start, Center, End) which have the values 0, 1, 2
	return f32(align) * 0.5
}

get_alignment_factors :: #force_inline proc(
	align_x: Alignment_X,
	align_y: Alignment_Y,
) -> base.Vec2 {
	return {get_alignment_factor(align_x), get_alignment_factor(align_y)}
}

get_axis_padding :: proc(padding: Padding) -> base.Vec2 {
	return base.Vec2{padding.left + padding.right, padding.top + padding.bottom}
}

get_padding_for_axis :: proc(padding: Padding, axis: Axis2) -> (f32, f32) {
	if axis == .X {
		return padding.left, padding.right
	}
	return padding.top, padding.bottom
}

get_padding_sum_for_axis :: proc(padding: Padding, axis: Axis2) -> f32 {
	if axis == .X {
		return padding.left + padding.right
	}
	return padding.top + padding.bottom
}

get_available_size :: proc(size: base.Vec2, padding: Padding) -> base.Vec2 {
	return {size.x - padding.left - padding.right, size.y - padding.top - padding.bottom}
}

layout_children_flow :: proc(parent: ^UI_Element) {
	padding := parent.config.layout.padding
	dir := parent.config.layout.layout_direction

	// Setup Axes
	main_axis, cross_axis := get_main_and_cross_axis(dir)

	// Resolve padding for axes
	pad_main_start, _ := get_padding_for_axis(padding, main_axis)
	pad_cross_start, _ := get_padding_for_axis(padding, cross_axis)

	// Calculate available content space
	available_size := get_available_size(parent.size, padding)

	start_pos_main := parent.position[main_axis] + pad_main_start
	start_pos_cross := parent.position[cross_axis] + pad_cross_start

	// Measure children
	total_children_main: f32 = 0
	max_children_cross: f32 = 0

	for child in parent.children {
		total_children_main += child.size[main_axis]
		max_children_cross = max(max_children_cross, child.size[cross_axis])
	}

	// Apply child gap
	gap_size := calc_child_gap(parent^)
	total_children_main += gap_size

	// Update Scroll region and clamp offsets
	// We always calculate bounds and clamp. If not scrollable, offset remain 0.
	parent.scroll_region.content_size[main_axis] = total_children_main
	parent.scroll_region.content_size[cross_axis] = max_children_cross

	max_offset_main := max(0.0, total_children_main - available_size[main_axis])

	max_offset_cross := max(0.0, max_children_cross - available_size[cross_axis])

	parent.scroll_region.max_offset[main_axis] = max_offset_main
	parent.scroll_region.max_offset[cross_axis] = max_offset_cross

	parent.scroll_region.offset[main_axis] = clamp(
		parent.scroll_region.offset[main_axis],
		0,
		max_offset_main,
	)
	parent.scroll_region.offset[cross_axis] = clamp(
		parent.scroll_region.offset[cross_axis],
		0,
		max_offset_cross,
	)

	// Determine starting position
	align_factors := get_alignment_factors(
		parent.config.layout.alignment_x,
		parent.config.layout.alignment_y,
	)

	remaining_space_main := available_size[main_axis] - total_children_main

	main_pos := start_pos_main + (remaining_space_main * align_factors[main_axis])

	// Adjust for scroll
	main_pos -= parent.scroll_region.offset[main_axis]

	// Position children
	for child in parent.children {
		// Main axis
		child.position[main_axis] = main_pos
		main_pos += child.size[main_axis] + parent.config.layout.child_gap

		// Cross axis
		remaining_space_cross := available_size[cross_axis] - child.size[cross_axis]

		child.position[cross_axis] =
			start_pos_cross +
			(remaining_space_cross * align_factors[cross_axis]) -
			parent.scroll_region.offset[cross_axis]
	}
}

layout_children_relative :: proc(parent: ^UI_Element) {
	// TODO(Thomas): Scrolling - I assume it makes sense here?
	padding := parent.config.layout.padding

	// Content box start and size
	content_pos := base.Vec2{parent.position.x + padding.left, parent.position.y + padding.top}
	available_content_size := get_available_size(parent.size, padding)

	for child in parent.children {
		factors := get_alignment_factors(
			child.config.layout.alignment_x,
			child.config.layout.alignment_y,
		)

		child.position =
			content_pos +
			(available_content_size * factors) +
			child.config.layout.relative_position
	}
}

calculate_positions_and_alignment :: proc(parent: ^UI_Element, dt: f32) {
	if parent == nil {
		return
	}

	base.animate_vec2(&parent.scroll_region.offset, &parent.scroll_region.target_offset, dt, 20.0)

	// Reset scroll content size for this frame
	parent.scroll_region.content_size = {}

	switch parent.config.layout.layout_mode {
	case .Flow:
		layout_children_flow(parent)
	case .Relative:
		layout_children_relative(parent)
	}

	// Recursive step
	for child in parent.children {
		calculate_positions_and_alignment(child, dt)
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
