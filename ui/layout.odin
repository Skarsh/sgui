package ui

import "core:log"
import "core:math"
import "core:mem"
import "core:strings"

import base "../base"
import textpkg "../text"

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

Position_Mode :: enum {
	Flow,
	Anchored,
}

Size_Kind :: enum {
	Fit,
	Fixed,
	Grow,
	Percentage,
}

Box :: struct {
	top:    f32,
	right:  f32,
	bottom: f32,
	left:   f32,
}

Padding :: distinct Box

Border :: distinct Box

Margin :: distinct Box

Text_Data :: struct {
	text:        string,
	text_layout: textpkg.Text_Layout,
}

Shape_Data :: struct {
	kind:      Shape_Kind,
	fill:      base.Fill,
	thickness: f32,
}

Element_Content :: struct {
	text_data:  Text_Data,
	texture_id: Maybe(Texture_Id),
	shape_data: Shape_Data,
}

Layout_Config :: struct {
	sizing:            [2]Sizing,
	padding:           Padding,
	margin:            Margin,
	child_gap:         f32,
	layout_direction:  Layout_Direction,
	relative_position: base.Vec2,
	alignment_x:       Alignment_X,
	alignment_y:       Alignment_Y,
	text_alignment_x:  Alignment_X,
	text_alignment_y:  Alignment_Y,
	text_wrap_mode:    textpkg.Text_Wrap_Mode,
	// Mapping: x=top-left, y=top-right, z=bottom-right, w=bottom-left
	border_radius:     base.Vec4,
	border:            Border,
	position_mode:     Position_Mode,
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
	parent:            ^UI_Element,
	id_string:         string,
	key:               UI_Key,
	position:          base.Vec2,
	min_size:          base.Vec2,
	max_size:          base.Vec2,
	size:              base.Vec2,
	text_content_size: base.Vec2,
	scroll_region:     Scroll_Region,
	config:            Element_Config,
	children:          [dynamic]^UI_Element,
	fill:              base.Fill,
	z_index:           i32,
	hot:               f32,
	active:            f32,
	last_comm:         Comm,
	last_frame_idx:    u64,
}

Sizing :: struct {
	kind:        Size_Kind,
	min_value:   f32,
	max_value:   f32,
	value:       f32,
	grow_factor: f32,
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

// Attaches text content to an element and records its intrinsic size.
// The element's sizing mode (Fit, Fixed, Grow) determines how the text affects layout:
// - Fit: Element sizes to fit text content
// - Fixed: Element uses specified size, text renders within
// - Grow: Element can grow/shrink, text wraps as needed
element_equip_text :: proc(
	ctx: ^Context,
	element: ^UI_Element,
	text: string,
	text_fill: base.Fill = {},
) -> mem.Allocator_Error {
	element.config.capability_flags |= {.Text}

	if element.config.text_fill == nil {
		if text_fill == nil {
			element.config.text_fill = base.fill_color(255, 255, 255)
		} else {
			element.config.text_fill = text_fill
		}
	}

	element.config.content.text_data = Text_Data {
		text = text,
	}

	// Measure text to record intrinsic content size
	text_layout := textpkg.layout_text(
		text,
		math.F32_MAX,
		ctx.font_id,
		ctx.interaction.text_measurement^,
		ctx.frame_allocator,
		element.config.layout.text_wrap_mode,
	) or_return

	// Calculate total content size including padding and border
	padding := element.config.layout.padding
	border := element.config.layout.border

	element.text_content_size = base.Vec2 {
		text_layout.size.x + padding.left + padding.right + border.left + border.right,
		text_layout.size.y + padding.top + padding.bottom + border.top + border.bottom,
	}

	// Set initial element size based on text content (for Fit/Grow sizing)
	// Fixed sizing keeps its specified size
	sizing_x := element.config.layout.sizing.x
	sizing_y := element.config.layout.sizing.y

	if sizing_x.kind != .Fixed {
		element.size.x = math.clamp(
			element.text_content_size.x,
			element.min_size.x,
			element.max_size.x,
		)
	}

	if sizing_y.kind != .Fixed {
		element.size.y = math.clamp(
			element.text_content_size.y,
			element.min_size.y,
			element.max_size.y,
		)
	}
	return nil
}

element_equip_shape :: proc(element: ^UI_Element, shape_data: Shape_Data) {
	assert(element != nil)
	element.config.capability_flags |= {.Shape}
	element.config.content.shape_data = shape_data
}

element_equip_image :: proc(element: ^UI_Element, texture_id: Texture_Id) {
	assert(element != nil)
	element.config.capability_flags |= {.Image}
	element.config.content.texture_id = texture_id
}

@(require_results)
calc_child_gap :: #force_inline proc(element: UI_Element) -> f32 {

	result: f32 = 0
	if len(element.children) > 0 {
		// Only flow children counts towards the child_gap
		flow_children: int
		for child in element.children {
			if child.config.layout.position_mode == .Flow {
				flow_children += 1
			}
		}
		result = f32(flow_children - 1) * element.config.layout.child_gap
	}

	assert(result >= 0)
	return result
}


// TODO(Thomas): This can be simplified further by combining into a Vec2, but not sure if that
// helps much since the layout algorithm needs to update per axis anyway.
@(require_results)
calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) -> f32 {
	assert(element != nil)

	padding := element.config.layout.padding
	border := element.config.layout.border
	padding_sum := get_padding_sum_for_axis(padding, axis)
	border_sum := get_border_sum_for_axis(border, axis)

	content_size: f32

	if is_main_axis(element^, axis) {
		// Main Axis: Accumulate size of all children plus gaps
		for child in element.children {
			if child.config.layout.position_mode == .Flow {
				content_size += child.size[axis]
			}
		}
		content_size += calc_child_gap(element^)
	} else {
		// Cross Axis: The size is determined by the largest child
		for child in element.children {
			if child.config.layout.position_mode == .Flow {
				content_size = max(content_size, child.size[axis])
			}
		}
	}

	total_size: f32
	// Also consider text content size (text_content_size already includes padding + border)
	if .Text in element.config.capability_flags {
		content_size = max(
			content_size + padding_sum + border_sum,
			element.text_content_size[axis],
		)

		total_size = math.clamp(content_size, element.min_size[axis], element.max_size[axis])
	} else {

		// Add padding and borders
		total_size = content_size + padding_sum + border_sum

		// Clamp to min/max size constraints
		total_size = math.clamp(total_size, element.min_size[axis], element.max_size[axis])
	}

	assert(total_size >= 0)
	return total_size
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent
	}
}

@(require_results)
open_element :: proc(
	ctx: ^Context,
	id: string,
	style: Style = {},
	default_style: Style = {},
) -> (
	^UI_Element,
	bool,
) {
	final_config := resolve_style(ctx, style, default_style)

	element, element_ok := make_element(ctx, id, final_config)
	assert(element_ok)
	if !element_ok {
		panic("Cannot proceed when failing to make_element, panic")
	}

	if push(&ctx.element_stack, element) {
		element.z_index = ctx.element_stack.top
	} else {
		return {}, false
	}
	ctx.current_parent = element

	comm, comm_alloc_err := build_comm(&ctx.interaction, element)
	assert(comm_alloc_err == .None)
	element.last_comm = comm

	return element, true
}

begin_container :: proc(ctx: ^Context, id: string, style: Style = {}) -> Comm {
	element, open_ok := open_element(ctx, id, style)
	assert(open_ok)
	return element.last_comm
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

container_basic :: proc(ctx: ^Context, id: string, body: proc(ctx: ^Context) = nil) -> Comm {
	comm := begin_container(ctx, id)
	if body != nil {
		body(ctx)
	}
	end_container(ctx)
	return comm
}

container_styled :: proc(
	ctx: ^Context,
	id: string,
	style: Style,
	body: proc(ctx: ^Context) = nil,
) -> Comm {
	comm := begin_container(ctx, id, style)
	if body != nil {
		body(ctx)
	}
	end_container(ctx)
	return comm
}

container_data :: proc(
	ctx: ^Context,
	id: string,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) -> Comm {
	comm := begin_container(ctx, id)
	if body != nil {
		body(ctx, data)
	}
	end_container(ctx)
	return comm
}

container_data_styled :: proc(
	ctx: ^Context,
	id: string,
	style: Style,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
) -> Comm {
	comm := begin_container(ctx, id, style)
	if body != nil {
		body(ctx, data)
	}
	end_container(ctx)
	return comm
}

fit_size_axis :: proc(element: ^UI_Element, axis: Axis2) {
	for child in element.children {
		fit_size_axis(child, axis)
	}

	if element.config.layout.sizing[axis].kind == .Fit {
		calc_element_fit_size_for_axis(element, axis)
	}
}

// TODO(Thomas): Remove early returns to simplify control flow
update_parent_element_fit_size_for_axis :: proc(element: ^UI_Element, axis: Axis2) {
	parent := element.parent

	if parent == nil {
		return
	}

	if parent.config.layout.sizing[axis].kind != .Fit {
		return
	}

	// Anchored elements should not contribute to parent sizes
	if element.config.layout.position_mode == .Anchored {
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
@(require_results)
calc_remaining_size :: #force_inline proc(element: UI_Element, axis: Axis2) -> f32 {
	padding := element.config.layout.padding
	border := element.config.layout.border
	padding_sum := get_padding_sum_for_axis(padding, axis)
	border_sum := get_border_sum_for_axis(border, axis)

	remaining_size := math.clamp(
		element.size[axis] - padding_sum - border_sum,
		0,
		element.size[axis],
	)

	assert(remaining_size >= 0)
	return remaining_size
}

@(require_results)
is_main_axis :: proc(element: UI_Element, axis: Axis2) -> bool {

	is_main_axis :=
		(axis == .X && element.config.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.config.layout.layout_direction == .Top_To_Bottom)

	return is_main_axis
}

@(require_results)
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
	assert(element != nil)

	if element != nil {
		if element.config.layout.sizing[axis].kind == .Fit && !is_main_axis(element^, axis) {
			content_size_on_axis := calc_remaining_size(element^, axis)
			for child in element.children {
				child_sizing_kind := child.config.layout.sizing[axis].kind
				if child_sizing_kind != .Fixed && child_sizing_kind != .Percentage {
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
}


// Target-based distribution: elements are sized to match their factor ratios
// e.g., factors 1:2:1 in 400px → sizes 100:200:100
// The caller passing in the allocator has the responsibility of freeing the allocated memory.
RESIZE_ITER_MAX :: 32
resolve_grow_sizes_for_children :: proc(
	element: ^UI_Element,
	axis: Axis2,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {

	if has_flow_children(element^) {
		resizables := make([dynamic]^UI_Element, allocator) or_return
		main_axis := is_main_axis(element^, axis)

		if main_axis {
			padding := element.config.layout.padding
			border := element.config.layout.border
			padding_sum := get_padding_sum_for_axis(padding, axis)
			border_sum := get_border_sum_for_axis(border, axis)
			child_gap := calc_child_gap(element^)

			// Calculate space used by non-grow elements
			fixed_space: f32 = padding_sum + border_sum + child_gap
			for child in element.children {
				if child.config.layout.position_mode == .Flow {
					if child.config.layout.sizing[axis].kind != .Grow {
						fixed_space += child.size[axis]
					}
				}
			}

			// Available space for grow elements
			available_for_grow := element.size[axis] - fixed_space

			// Collect grow elements with positive factor
			for child in element.children {
				if child.config.layout.position_mode == .Flow {
					if child.config.layout.sizing[axis].kind == .Grow {
						factor := child.config.layout.sizing[axis].grow_factor
						if factor > 0 {
							append(&resizables, child) or_return
						}
					}
				}
			}

			if len(resizables) > 0 {
				// Iteratively assign target sizes, handling constraints
				resize_iter := 0
				for resize_iter < RESIZE_ITER_MAX && len(resizables) > 0 {
					resize_iter += 1

					// Calculate total factor for current resizables
					total_factor: f32 = 0
					for child in resizables {
						total_factor += child.config.layout.sizing[axis].grow_factor
					}

					if base.approx_equal(total_factor, 0, EPSILON) {
						break
					}

					any_clamped := false

					// Calculate and apply target sizes
					#reverse for child, idx in resizables {
						child_factor := child.config.layout.sizing[axis].grow_factor
						target_size := (child_factor / total_factor) * available_for_grow
						clamped_size := clamp(
							target_size,
							child.min_size[axis],
							child.max_size[axis],
						)

						child.size[axis] = clamped_size

						// If clamped, remove from pool and adjust available space
						if !base.approx_equal(clamped_size, target_size, EPSILON) {
							unordered_remove(&resizables, idx)
							available_for_grow -= clamped_size
							any_clamped = true
						}
					}

					// If no constraints were hit, we're done
					if !any_clamped {
						break
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

	return nil
}

resolve_percentage_sizes_for_children :: proc(parent: ^UI_Element, axis: Axis2) {
	parent_padding := parent.config.layout.padding
	parent_border := parent.config.layout.border
	parent_content_available_size := get_available_size(parent.size, parent_padding, parent_border)

	for child in parent.children {
		sizing_info := child.config.layout.sizing[axis]
		if sizing_info.kind == .Percentage {
			percentage := clamp(sizing_info.value, 0.0, 1.0)
			child.size[axis] = parent_content_available_size[axis] * percentage
		}
	}
}

resolve_dependent_sizes_for_axis :: proc(
	element: ^UI_Element,
	axis: Axis2,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {
	if element == nil {
		return nil
	}

	resolve_percentage_sizes_for_children(element, axis)
	resolve_grow_sizes_for_children(element, axis, allocator) or_return

	for child in element.children {
		resolve_dependent_sizes_for_axis(child, axis, allocator) or_return
	}
	return nil
}

wrap_text :: proc(
	ctx: ^Context,
	element: ^UI_Element,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {
	if .Text in element.config.capability_flags {
		border := element.config.layout.border
		padding := element.config.layout.padding
		text := element.config.content.text_data.text
		text_wrap_mode := element.config.layout.text_wrap_mode

		// Determine available width for text wrapping
		// Use parent's available space if it's more constrained than element's size
		element_available := get_available_size(element.size, padding, border)
		wrap_width := element_available.x

		sizing_x_kind := element.config.layout.sizing.x.kind
		if element.parent != nil {
			parent := element.parent
			parent_padding := parent.config.layout.padding
			parent_border := parent.config.layout.border
			parent_available := get_available_size(parent.size, parent_padding, parent_border)

			// If parent has less space, use that and account for text's own padding/border,
			// unless it's text_wrap_mode .None, then allow overflow
			if parent_available.x < element.size.x && text_wrap_mode != .None {
				wrap_width =
					parent_available.x - padding.left - padding.right - border.left - border.right
			}

			// Constrain element width to parent's available space for Fit sizing
			// unless it's text_wrap_mode .None
			if sizing_x_kind == .Fit && text_wrap_mode != .None {
				if parent_available.x < element.size.x {
					element.size.x = math.clamp(
						parent_available.x,
						element.min_size.x,
						element.max_size.x,
					)
				}
			}
		}

		// TODO(Thomas): If the wrap mode is extend, this should probably grow the ui element.
		// How should that work?
		text_layout := textpkg.layout_text(
			text,
			wrap_width,
			ctx.font_id,
			ctx.interaction.text_measurement^,
			allocator,
			text_wrap_mode,
		) or_return

		element.config.content.text_data.text_layout = text_layout

		// Update text_content_size.y based on wrapped height
		final_height :=
			text_layout.size.y + padding.top + padding.bottom + border.top + border.bottom
		element.text_content_size.y = final_height

		// Update element size for Fit and Grow sizing (not Fixed)
		sizing_y_kind := element.config.layout.sizing.y.kind
		if sizing_y_kind == .Fit || sizing_y_kind == .Grow {
			element.size.y = math.clamp(final_height, element.min_size.y, element.max_size.y)
		}
	}

	for child in element.children {
		wrap_text(ctx, child, allocator) or_return
	}
	return nil
}

@(require_results)
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
		element.key = key
		assert(str_clone_err == .None)
		if str_clone_err != .None {
			log.error("failed to allocate memory for cloning id string")
			return nil, false
		}


		element.children, err = make([dynamic]^UI_Element, ctx.frame_allocator)
		assert(err == .None)

	} else {
		// Cached Element
		found := false
		element, found = ctx.element_cache[key]

		if found {
			assert(
				ctx.frame_idx > element.last_frame_idx,
				"adding two elements with the same id / key on the same frame is not allowed",
			)
		} else {
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
			element.key = key
			assert(str_clone_err == .None)
			if str_clone_err != .None {
				log.error("failed to allocate memory for cloning id string")
				return nil, false
			}
			element.children, err = make([dynamic]^UI_Element, ctx.persistent_allocator)
			assert(err == .None)
			ctx.element_cache[key] = element
		}
	}


	// TODO(Thomas): I don't think this is very clean.
	// This has to happen before the incremeting in update_element_configuration
	// This makes sure that elements that were not present this frame gets their
	// animations reset, so the don't "freeze" if being hidden etc.
	was_absent := element.last_frame_idx < ctx.frame_idx - 1
	if was_absent {
		element.hot = 0
		element.active = 0
	}

	update_element_configuration(element, element_config, ctx.frame_idx)

	element.parent = ctx.current_parent
	clear_dynamic_array(&element.children)
	if element.parent != nil {
		append(&element.parent.children, element)
	}

	return element, true
}

@(require_results)
element_rect :: proc(element: UI_Element) -> base.Rect {
	return base.Rect {
		i32(element.position.x),
		i32(element.position.y),
		i32(element.size.x),
		i32(element.size.y),
	}
}

@(require_results)
get_alignment_factor :: #force_inline proc(align: $E) -> f32 {
	// NOTE(Thomas): This works because Alignment_X and Alignment_Y are both
	// representing the positions (Start, Center, End) which have the values 0, 1, 2
	result := f32(align) * 0.5
	assert(result >= 0)
	return result
}

@(require_results)
get_alignment_factors :: #force_inline proc(
	align_x: Alignment_X,
	align_y: Alignment_Y,
) -> base.Vec2 {
	return {get_alignment_factor(align_x), get_alignment_factor(align_y)}
}

@(require_results)
get_axis_padding :: proc(padding: Padding) -> base.Vec2 {
	return base.Vec2{padding.left + padding.right, padding.top + padding.bottom}
}

@(require_results)
get_padding_for_axis :: proc(padding: Padding, axis: Axis2) -> (f32, f32) {
	if axis == .X {
		return padding.left, padding.right
	} else {
		return padding.top, padding.bottom
	}
}

// Generic helper for summing box values (padding, border, margin) for a given axis
@(require_results)
get_box_sum_for_axis :: proc(box: Box, axis: Axis2) -> f32 {
	if axis == .X {
		return box.left + box.right
	} else {
		return box.top + box.bottom
	}
}

@(require_results)
get_padding_sum_for_axis :: proc(padding: Padding, axis: Axis2) -> f32 {
	return get_box_sum_for_axis(Box(padding), axis)
}

@(require_results)
get_border_sum_for_axis :: proc(border: Border, axis: Axis2) -> f32 {
	return get_box_sum_for_axis(Box(border), axis)
}

@(require_results)
get_border_for_axis :: proc(border: Border, axis: Axis2) -> (f32, f32) {
	if axis == .X {
		return border.left, border.right
	} else {
		return border.top, border.bottom
	}
}

@(require_results)
get_margin_for_axis :: proc(margin: Margin, axis: Axis2) -> (f32, f32) {
	if axis == .X {
		return margin.left, margin.right
	} else {
		return margin.top, margin.bottom
	}
}

@(require_results)
get_margin_sum_for_axis :: proc(margin: Margin, axis: Axis2) -> f32 {
	return get_box_sum_for_axis(Box(margin), axis)
}

@(require_results)
get_available_size :: proc(size: base.Vec2, padding: Padding, border: Border) -> base.Vec2 {
	available_x := size.x - padding.left - padding.right - border.left - border.right
	available_y := size.y - padding.top - padding.bottom - border.top - border.bottom
	result := base.Vec2{math.clamp(available_x, 0, size.x), math.clamp(available_y, 0, size.y)}

	assert(result.x >= 0)
	assert(result.y >= 0)

	return result
}

@(require_results)
has_flow_children :: #force_inline proc(element: UI_Element) -> bool {
	result := false
	for child in element.children {
		if child.config.layout.position_mode == .Flow {
			result = true
			break
		}
	}
	return result
}

layout_child_anchored :: proc(parent: ^UI_Element, child: ^UI_Element) {
	padding := parent.config.layout.padding
	border := parent.config.layout.border

	content_origin := base.Vec2 {
		parent.position.x + padding.left + border.left,
		parent.position.y + padding.top + border.top,
	}

	available := get_available_size(parent.size, padding, border)

	child_margin := child.config.layout.margin
	relative_position := child.config.layout.relative_position

	factors := get_alignment_factors(
		child.config.layout.alignment_x,
		child.config.layout.alignment_y,
	)

	margin_size := base.Vec2 {
		child_margin.left + child_margin.right,
		child_margin.top + child_margin.bottom,
	}

	// Gives natural alignment, e.g. left side of child is aligned with left side of parent
	// when .Left for alignment_x, and right side of child is aligned with right side of parent
	// when .Right for alignment_x. Same for .Top and .Bottom for alignment_y.
	remaining :=
		base.Vec2{child_margin.left, child_margin.top} +
		(available - child.size - margin_size) * factors

	child.position = content_origin + remaining + relative_position
}

layout_children_in_flow :: proc(parent: ^UI_Element) {
	if has_flow_children(parent^) {

		padding := parent.config.layout.padding
		border := parent.config.layout.border
		dir := parent.config.layout.layout_direction

		// Setup Axes
		main_axis, cross_axis := get_main_and_cross_axis(dir)

		// Resolve padding for axes
		pad_main_start, _ := get_padding_for_axis(padding, main_axis)
		pad_cross_start, _ := get_padding_for_axis(padding, cross_axis)

		// Resolve border for axes
		border_main_start, _ := get_border_for_axis(border, main_axis)
		border_cross_start, _ := get_border_for_axis(border, cross_axis)

		// Calculate available content space
		available_size := get_available_size(parent.size, padding, border)

		start_pos_main := parent.position[main_axis] + pad_main_start + border_main_start
		start_pos_cross := parent.position[cross_axis] + pad_cross_start + border_cross_start

		// Measure children (including margins)
		total_children_main: f32 = 0
		max_children_cross: f32 = 0

		for child in parent.children {
			if child.config.layout.position_mode == .Flow {
				child_margin := child.config.layout.margin
				margin_main := get_margin_sum_for_axis(child_margin, main_axis)
				margin_cross := get_margin_sum_for_axis(child_margin, cross_axis)

				total_children_main += child.size[main_axis] + margin_main
				max_children_cross = max(max_children_cross, child.size[cross_axis] + margin_cross)
			}
		}

		// Apply child gap
		gap_size := calc_child_gap(parent^)
		total_children_main += gap_size

		// Update Scroll region and clamp offsets
		// We always calculate bounds and clamp. If not scrollable, clear the scroll_region.
		parent_flags := parent.config.capability_flags

		if .Scrollable_X in parent_flags || .Scrollable_Y in parent_flags {
			parent.scroll_region.content_size[main_axis] = total_children_main
			parent.scroll_region.content_size[cross_axis] = max_children_cross

			max_offset_main := max(0.0, total_children_main - available_size[main_axis])
			max_offset_cross := max(0.0, max_children_cross - available_size[cross_axis])

			parent.scroll_region.max_offset[main_axis] = max_offset_main
			parent.scroll_region.max_offset[cross_axis] = max_offset_cross

			// We always set the offset for both main axis and cross axis, even though
			// one of the axis might not have the Scrollable capability set.
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

			parent.scroll_region.target_offset[main_axis] = clamp(
				parent.scroll_region.target_offset[main_axis],
				0,
				max_offset_main,
			)

			parent.scroll_region.target_offset[cross_axis] = clamp(
				parent.scroll_region.target_offset[cross_axis],
				0,
				max_offset_cross,
			)

			// Clear offset if one of them is not set, only one can not be set at a time.
			if .Scrollable_X not_in parent_flags {
				parent.scroll_region.offset.x = 0
				parent.scroll_region.target_offset.x = 0
			} else if .Scrollable_Y not_in parent_flags {
				parent.scroll_region.offset.y = 0
				parent.scroll_region.target_offset.y = 0
			}

		} else {
			parent.scroll_region = Scroll_Region{}
		}

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
			if child.config.layout.position_mode == .Flow {
				child_margin := child.config.layout.margin
				margin_main_start, margin_main_end := get_margin_for_axis(child_margin, main_axis)
				margin_cross_start, margin_cross_end := get_margin_for_axis(
					child_margin,
					cross_axis,
				)

				// Main axis (apply start margin)
				child.position[main_axis] = main_pos + margin_main_start
				main_pos +=
					child.size[main_axis] +
					margin_main_start +
					margin_main_end +
					parent.config.layout.child_gap

				// Cross axis (apply start margin)
				remaining_space_cross :=
					available_size[cross_axis] -
					child.size[cross_axis] -
					margin_cross_start -
					margin_cross_end

				child.position[cross_axis] =
					start_pos_cross +
					margin_cross_start +
					(remaining_space_cross * align_factors[cross_axis]) -
					parent.scroll_region.offset[cross_axis]

			}
		}
	}
}

calculate_positions_and_alignment :: proc(parent: ^UI_Element, dt: f32) {
	assert(parent != nil)

	if parent != nil {
		base.animate_vec2(
			&parent.scroll_region.offset,
			&parent.scroll_region.target_offset,
			dt,
			20.0,
		)

		// Reset scroll content size for this frame
		parent.scroll_region.content_size = {}

		layout_children_in_flow(parent)

		for child in parent.children {
			if child.config.layout.position_mode == .Anchored {
				layout_child_anchored(parent, child)
			}
		}

		// Recursive step
		for child in parent.children {
			calculate_positions_and_alignment(child, dt)
		}
	}
}


// Helper to get an element in the element cache by id string.
// The returned UI_Element will be a copy of the one in the element cache.
@(require_results)
get_element_by_string_id :: proc(ctx: ^Context, id: string) -> (element: UI_Element, ok: bool) {
	key := ui_key_hash(id)
	element_ptr, found := ctx.element_cache[key]
	if found {
		element = element_ptr^
		ok = true
	}
	return
}

// Helper to get a pointer to an element in element cache by id string
@(require_results)
get_element_pointer_by_string_id :: proc(ctx: ^Context, id: string) -> (^UI_Element, bool) {
	key := ui_key_hash(id)
	return ctx.element_cache[key]
}

// Helper to get an element in element cache by key.
// The returned UI_Element will be a copy of the on in the element cache.
@(require_results)
get_element_by_key :: proc(ctx: ^Context, key: UI_Key) -> (UI_Element, bool) {
	element, ok := ctx.element_cache[key]
	return element^, ok
}

// Helper to get a pointer to an element in element cache by key.
@(require_results)
get_element_pointer_by_key :: proc(ctx: ^Context, key: UI_Key) -> (^UI_Element, bool) {
	return ctx.element_cache[key]
}


// Helper to print all the element_ids in the hierarchy
print_element_hierarchy :: proc(root: ^UI_Element) {
	assert(root != nil)

	if root != nil {
		log.infof("id: %v, size: %v, pos: %v", root.id_string, root.size, root.position)

		for child in root.children {
			print_element_hierarchy(child)
		}
	}
}
