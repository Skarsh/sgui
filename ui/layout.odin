package ui

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"

import base "../base"
import textpkg "../text"

EPSILON :: 0.001
MAX_GROW_FACTOR :: 1000

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
	text: string,
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
	alignment_x:       base.Alignment_X,
	alignment_y:       base.Alignment_Y,
	text_alignment_x:  base.Alignment_X,
	text_alignment_y:  base.Alignment_Y,
	text_wrap_mode:    textpkg.Text_Wrap_Mode,
	font_id:           int,
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
	name:              string,
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

@(require_results)
is_valid_sizing :: proc(sizing: Sizing) -> bool {
	valid := false
	switch sizing.kind {
	case .Fixed:
		valid = sizing.value >= 0 && sizing.value <= math.F32_MAX
	case .Fit, .Grow, .Percentage:
		valid =
			sizing.min_value >= 0 &&
			sizing.min_value <= sizing.max_value &&
			sizing.max_value <= math.F32_MAX
	}

	if sizing.kind == .Percentage {
		valid = valid && sizing.value >= 0 && sizing.value <= 1
	} else if sizing.kind == .Grow {
		valid = valid && sizing.grow_factor >= 0 && sizing.grow_factor <= MAX_GROW_FACTOR
	}

	return valid
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

element_equip_text :: proc(
	ctx: ^Context,
	element: ^UI_Element,
	text: string,
	text_fill: base.Fill = {},
) {
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

		// Make sure the fence post calculation of the children is >= 0
		result = max(f32(flow_children - 1), 0) * element.config.layout.child_gap
	}

	assert(result >= 0, "child gap must be >= 0")
	return result
}


// TODO(Thomas): This can be simplified further by combining into a Vec2, but not sure if that
// helps much since the layout algorithm needs to update per axis anyway.
@(require_results)
calculate_element_size_for_axis :: proc(element: ^UI_Element, axis: base.Axis2) -> f32 {
	assert(element != nil)

	padding := element.config.layout.padding
	border := element.config.layout.border
	padding_sum := get_padding_sum_for_axis(padding, axis)
	border_sum := get_border_sum_for_axis(border, axis)

	content_size := measure_flow_content_size(element^)[axis]
	total_size := content_size + padding_sum + border_sum

	// text content_size already includes padding and border
	if .Text in element.config.capability_flags {
		total_size = max(total_size, element.text_content_size[axis])
	}

	total_size = math.clamp(total_size, element.min_size[axis], element.max_size[axis])

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
	key: UI_Key,
	style: Style = {},
	default_style: Style = {},
	name: string = "",
) -> ^UI_Element {
	final_config := resolve_style(ctx, style, default_style)

	element := make_element(ctx, key, final_config, name)

	if push(&ctx.element_stack, element) {
		element.z_index = ctx.element_stack.top
	} else {
		panic("Unable to push element onto stack, panic")
	}
	ctx.current_parent = element

	comm, comm_alloc_err := build_comm(&ctx.interaction, element)
	assert(comm_alloc_err == .None)
	element.last_comm = comm

	return element
}

begin_container :: proc(
	ctx: ^Context,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, name = name)
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

container_basic :: proc(
	ctx: ^Context,
	body: proc(ctx: ^Context) = nil,
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	comm := begin_container(ctx, name = name, id = id, loc = loc)
	if body != nil {
		body(ctx)
	}
	end_container(ctx)
	return comm
}

container_styled :: proc(
	ctx: ^Context,
	style: Style,
	body: proc(ctx: ^Context) = nil,
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {

	comm := begin_container(ctx, style, name = name, id = id, loc = loc)
	if body != nil {
		body(ctx)
	}
	end_container(ctx)
	return comm
}

container_data :: proc(
	ctx: ^Context,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	comm := begin_container(ctx, name = name, id = id, loc = loc)
	if body != nil {
		body(ctx, data)
	}
	end_container(ctx)
	return comm
}

container_data_styled :: proc(
	ctx: ^Context,
	style: Style,
	data: ^$T,
	body: proc(ctx: ^Context, data: ^T) = nil,
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	comm := begin_container(ctx, style, name = name, id = id, loc = loc)
	if body != nil {
		body(ctx, data)
	}
	end_container(ctx)
	return comm
}

measure_intrinsic_size_for_axis :: proc(element: ^UI_Element, axis: base.Axis2) {
	for child in element.children {
		measure_intrinsic_size_for_axis(child, axis)
	}

	sizing_kind := element.config.layout.sizing[axis].kind
	if sizing_kind == .Fit || sizing_kind == .Grow {
		element.size[axis] = calculate_element_size_for_axis(element, axis)
	}
}

@(require_results)
is_main_axis :: proc(element: UI_Element, axis: base.Axis2) -> bool {

	is_main_axis :=
		(axis == .X && element.config.layout.layout_direction == .Left_To_Right) ||
		(axis == .Y && element.config.layout.layout_direction == .Top_To_Bottom)

	return is_main_axis
}

@(require_results)
get_main_and_cross_axis :: proc(
	layout_direction: Layout_Direction,
) -> (
	main_axis: base.Axis2,
	cross_axis: base.Axis2,
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

// Target-based distribution: elements are sized to match their factor ratios
// e.g., factors 1:2:1 in 400px -> sizes 100:200:100
// The caller passing in the allocator has the responsibility of freeing the allocated memory.
RESIZE_ITER_MAX :: 32
resolve_grow_sizes_for_children :: proc(
	element: ^UI_Element,
	axis: base.Axis2,
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

			fixed_space: f32 = padding_sum + border_sum + child_gap
			for child in element.children {
				if child.config.layout.position_mode == .Flow {
					fixed_space += get_margin_sum_for_axis(child.config.layout.margin, axis)

					sizing_info := child.config.layout.sizing[axis]
					if sizing_info.kind == .Grow && sizing_info.grow_factor > 0 {
						append(&resizables, child) or_return
					} else {
						fixed_space += child.size[axis]
					}
				}
			}

			available_for_grow := element.size[axis] - fixed_space

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
			remaining_size := content_box(element^).size[axis]
			for child in element.children {
				if child.config.layout.sizing[axis].kind == .Grow {
					margin_sum := get_margin_sum_for_axis(child.config.layout.margin, axis)

					child.size[axis] = clamp(
						remaining_size - margin_sum,
						child.min_size[axis],
						child.max_size[axis],
					)
				}
			}
		}
	}

	return nil
}

resolve_percentage_sizes_for_children :: proc(element: ^UI_Element, axis: base.Axis2) {
	content_available_size := content_box(element^).size

	for child in element.children {
		sizing_info := child.config.layout.sizing[axis]
		if sizing_info.kind == .Percentage {
			child.size[axis] = clamp(
				content_available_size[axis] * sizing_info.value,
				child.min_size[axis],
				child.max_size[axis],
			)
		}
	}
}

resolve_dependent_sizes_for_axis :: proc(
	element: ^UI_Element,
	axis: base.Axis2,
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

// TODO(Thomas): @Speed This could probably check if the element has fit sizing on
// any of the axes, because I'm pretty sure that's the only case where this really matters.
// The element's sizing mode (Fit, Fixed, Grow) determines how the text affects layout:
// - Fit: Element sizes to fit text content
// - Fixed: Element uses specified size, text renders within
// - Grow: Element can grow/shrink, text wraps as needed
measure_text_sizes :: proc(ctx: ^Context, element: ^UI_Element) {
	if .Text in element.config.capability_flags {
		intrinsic := textpkg.measure_text_intrinsic(
			element.config.content.text_data.text,
			&ctx.text_system,
			element.config.layout.font_id,
		)

		padding := element.config.layout.padding
		border := element.config.layout.border

		element.text_content_size = base.Vec2 {
			intrinsic.x + padding.left + padding.right + border.left + border.right,
			intrinsic.y + padding.top + padding.bottom + border.top + border.bottom,
		}

		if element.config.layout.sizing.x.kind != .Fixed {
			element.size.x = math.clamp(
				element.text_content_size.x,
				element.min_size.x,
				element.max_size.x,
			)
		}

		if element.config.layout.sizing.y.kind != .Fixed {
			element.size.y = math.clamp(
				element.text_content_size.y,
				element.min_size.y,
				element.max_size.y,
			)
		}
	}

	for child in element.children {
		measure_text_sizes(ctx, child)
	}
}

wrap_text :: proc(ctx: ^Context, element: ^UI_Element) -> mem.Allocator_Error {
	if .Text in element.config.capability_flags {
		border := element.config.layout.border
		padding := element.config.layout.padding
		text := element.config.content.text_data.text
		text_wrap_mode := element.config.layout.text_wrap_mode

		// Determine available width for text wrapping
		// Use parent's available space if it's more constrained than element's size
		wrap_width := content_box(element^).size.x

		sizing_x_kind := element.config.layout.sizing.x.kind
		if element.parent != nil {
			parent := element.parent
			parent_available := content_box(parent^).size

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

		text_layout := textpkg.layout_text_cached(
			&ctx.text_system,
			{
				key = element.key.hash,
				frame_idx = ctx.frame_idx,
				text = text,
				params = {
					wrap_width,
					element.config.layout.font_id,
					element.config.layout.text_alignment_x,
					text_wrap_mode,
				},
			},
			ctx.persistent_allocator,
			ctx.frame_allocator,
		) or_return


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
		wrap_text(ctx, child) or_return
	}
	return nil
}

// Always returns a usable element, will panic on invalid sizing or allocation failure.
@(require_results)
make_element :: proc(
	ctx: ^Context,
	key: UI_Key,
	element_config: Element_Config,
	name: string,
) -> ^UI_Element {

	for axis in base.Axis2 {
		sizing := element_config.layout.sizing[axis]
		fmt.assertf(
			is_valid_sizing(sizing),
			"invalid %v sizing for element %q: %v",
			axis,
			name,
			sizing,
		)
	}

	update_element_configuration :: proc(element: ^UI_Element, config: Element_Config, idx: u64) {
		element.last_frame_idx = idx
		element.config = config
		element.fill = config.background_fill

		element.min_size.x = config.layout.sizing.x.min_value
		element.min_size.y = config.layout.sizing.y.min_value

		element.max_size.x = config.layout.sizing.x.max_value
		element.max_size.y = config.layout.sizing.y.max_value

		if config.layout.sizing.x.kind == .Fixed {
			element.size.x = config.layout.sizing.x.value
		}

		if config.layout.sizing.y.kind == .Fixed {
			element.size.y = config.layout.sizing.y.value
		}
	}

	element: ^UI_Element

	if key == ui_key_null() {
		// Non-cached / Temporary Element
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.frame_allocator)
		assert(err == .None, fmt.tprintf("failed to allocate UI_Element: %v", err))

		element.key = key

		// TODO(Thomas): @Perf The string cloning here has now moved to be only for elements
		// that has a non-empty string name. But this is still unnecessary to do in production
		// builds, so we should gate this by checking whether a prod build or not when we
		// get that up and running, since this is mostly for debugging purposes.
		if name != "" {
			str_clone_err: mem.Allocator_Error
			element.name, str_clone_err = strings.clone(name, ctx.frame_allocator)
			assert(
				str_clone_err == .None,
				fmt.tprintf(
					"failed to allocate memory for cloning name string: %v",
					str_clone_err,
				),
			)
		}

		element.children, err = make([dynamic]^UI_Element, ctx.frame_allocator)
		assert(err == .None, fmt.tprintf("failed to allocate UI_element children: %v", err))

	} else {
		// Cached Element
		found := false
		element, found = ctx.element_cache[key]

		if found {
			fmt.assertf(
				ctx.frame_idx > element.last_frame_idx,
				"adding two elements with the same id / key on the same frame is not allowed: " +
				"key %v, new element name %q, existing element name %q",
				key.hash,
				name,
				element.name,
			)
		} else {
			err: mem.Allocator_Error
			element, err = new(UI_Element, ctx.persistent_allocator)
			if err != .None {
				log.panicf("failed to allocate UI_Element: %v", err)
			}


			element.key = key

			// TODO(Thomas): @Perf The string cloning here has now moved to be only for elements
			// that has a non-empty string name. But this is still unnecessary to do in production
			// builds, so we should gate this by checking whether a prod build or not when we
			// get that up and running, since this is mostly for debugging purposes.
			if name != "" {
				str_clone_err: mem.Allocator_Error
				element.name, str_clone_err = strings.clone(name, ctx.persistent_allocator)
				if str_clone_err != .None {
					log.panicf(
						"failed to allocate memory for cloning id string: %v",
						str_clone_err,
					)
				}
			}

			element.children, err = make([dynamic]^UI_Element, ctx.persistent_allocator)
			if err != .None {
				log.panicf("failed to allocate UI_Element children: %v", err)
			}
			ctx.element_cache[key] = element
		}
	}


	// TODO(Thomas): I don't think this is very clean.
	// This has to happen before the incrementing in update_element_configuration
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
		_, append_err := append(&element.parent.children, element)
		if append_err != .None {
			log.panicf("failed to append element to its parent: %v", append_err)
		}
	}

	return element
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
	align_x: base.Alignment_X,
	align_y: base.Alignment_Y,
) -> base.Vec2 {
	return {get_alignment_factor(align_x), get_alignment_factor(align_y)}
}

// Generic helper for summing box values (padding, border, margin) for a given axis
@(require_results)
get_box_sum_for_axis :: proc(box: Box, axis: base.Axis2) -> f32 {
	if axis == .X {
		return box.left + box.right
	} else {
		return box.top + box.bottom
	}
}

@(require_results)
get_padding_sum_for_axis :: proc(padding: Padding, axis: base.Axis2) -> f32 {
	return get_box_sum_for_axis(Box(padding), axis)
}

@(require_results)
get_border_sum_for_axis :: proc(border: Border, axis: base.Axis2) -> f32 {
	return get_box_sum_for_axis(Box(border), axis)
}

@(require_results)
get_margin_for_axis :: proc(margin: Margin, axis: base.Axis2) -> (f32, f32) {
	if axis == .X {
		return margin.left, margin.right
	} else {
		return margin.top, margin.bottom
	}
}

@(require_results)
get_margin_sum_for_axis :: proc(margin: Margin, axis: base.Axis2) -> f32 {
	return get_box_sum_for_axis(Box(margin), axis)
}

// The inner content box of an element, inset by padding and border.
// origin is the top left where content starts, size is the space available for it.
Content_Box :: struct {
	origin: base.Vec2,
	size:   base.Vec2,
}

@(require_results)
content_box :: proc(element: UI_Element) -> Content_Box {
	padding := element.config.layout.padding
	border := element.config.layout.border
	size := element.size

	available_x := size.x - padding.left - padding.right - border.left - border.right
	available_y := size.y - padding.top - padding.bottom - border.top - border.bottom
	result_size := base.Vec2 {
		math.clamp(available_x, 0, size.x),
		math.clamp(available_y, 0, size.y),
	}

	assert(result_size.x >= 0)
	assert(result_size.y >= 0)

	return Content_Box {
		origin = element.position + {padding.left + border.left, padding.top + border.top},
		size = result_size,
	}
}

@(require_results)
content_origin_scrolled :: proc(element: UI_Element) -> base.Vec2 {
	return content_box(element).origin - element.scroll_region.offset
}

// Text origin in screen space
@(require_results)
text_origin :: proc(element: UI_Element, text_layout: textpkg.Text_Layout) -> base.Vec2 {
	start_pos := content_origin_scrolled(element)
	box := content_box(element)
	switch element.config.layout.text_alignment_y {
	case .Top:
	// No change
	case .Center:
		start_pos.y = start_pos.y + (box.size.y - text_layout.size.y) / 2
	case .Bottom:
		start_pos.y = start_pos.y + (box.size.y - text_layout.size.y)
	}
	return start_pos
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

position_anchored_children :: proc(element: ^UI_Element) {
	for child in element.children {
		if child.config.layout.position_mode == .Anchored {

			box := content_box(element^)

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
				(box.size - child.size - margin_size) * factors

			child.position = box.origin + remaining + relative_position
		}
	}
}

@(require_results)
measure_flow_content_size :: proc(element: UI_Element) -> (content_size: base.Vec2) {
	if has_flow_children(element) {

		dir := element.config.layout.layout_direction
		main_axis, cross_axis := get_main_and_cross_axis(dir)

		// Measure children (including margins)
		for child in element.children {
			if child.config.layout.position_mode == .Flow {
				child_margin := child.config.layout.margin
				margin_main := get_margin_sum_for_axis(child_margin, main_axis)
				margin_cross := get_margin_sum_for_axis(child_margin, cross_axis)

				content_size[main_axis] += child.size[main_axis] + margin_main
				content_size[cross_axis] = max(
					content_size[cross_axis],
					child.size[cross_axis] + margin_cross,
				)
			}
		}

		// Apply child gap
		gap_size := calc_child_gap(element)
		content_size[main_axis] += gap_size
	}

	return
}

update_scroll_region :: proc(ctx: ^Context, element: ^UI_Element) {
	flags := element.config.capability_flags

	if .Scrollable_X in flags || .Scrollable_Y in flags {
		// Reset scroll_region content_size
		element.scroll_region.content_size = {}

		available_size := content_box(element^).size
		content_size := measure_flow_content_size(element^)

		if .Text in flags {
			text_size := base.Vec2{}

			if text_layout, found := textpkg.read_text_layout_cache(
				ctx.text_system.layout_cache,
				element.key.hash,
			); found {
				text_size = text_layout.size
			}

			content_size.x = max(content_size.x, text_size.x)
			content_size.y = max(content_size.y, text_size.y)
		}

		max_offset := base.Vec2{}
		max_offset.x = max(0.0, content_size.x - available_size.x)
		max_offset.y = max(0.0, content_size.y - available_size.y)

		if .Scrollable_X not_in flags do max_offset.x = 0
		if .Scrollable_Y not_in flags do max_offset.y = 0

		element.scroll_region.content_size = content_size
		element.scroll_region.max_offset = max_offset
		for axis in base.Axis2 {
			element.scroll_region.offset[axis] = clamp(
				element.scroll_region.offset[axis],
				0,
				max_offset[axis],
			)
			element.scroll_region.target_offset[axis] = clamp(
				element.scroll_region.target_offset[axis],
				0,
				max_offset[axis],
			)
		}
	}
}

position_flow_children :: proc(element: ^UI_Element) {
	if has_flow_children(element^) {
		// Setup Axes
		dir := element.config.layout.layout_direction
		main_axis, cross_axis := get_main_and_cross_axis(dir)

		box := content_box(element^)
		available_size := box.size

		// Content size
		content_size := measure_flow_content_size(element^)
		remaining_space_main := available_size[main_axis] - content_size[main_axis]

		// Determine starting position
		start_pos := box.origin
		align_factors := get_alignment_factors(
			element.config.layout.alignment_x,
			element.config.layout.alignment_y,
		)
		main_pos := start_pos[main_axis] + (remaining_space_main * align_factors[main_axis])

		// Adjust for scroll
		main_pos -= element.scroll_region.offset[main_axis]

		// Position children
		for child in element.children {
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
					element.config.layout.child_gap

				// Cross axis (apply start margin)
				remaining_space_cross :=
					available_size[cross_axis] -
					child.size[cross_axis] -
					margin_cross_start -
					margin_cross_end

				child.position[cross_axis] =
					start_pos[cross_axis] +
					margin_cross_start +
					(remaining_space_cross * align_factors[cross_axis]) -
					element.scroll_region.offset[cross_axis]
			}
		}
	}
}

calculate_positions_and_alignment :: proc(ctx: ^Context, element: ^UI_Element, dt: f32) {
	assert(element != nil)

	if element != nil {
		base.animate_vec2(
			&element.scroll_region.offset,
			&element.scroll_region.target_offset,
			dt,
			20.0,
		)

		update_scroll_region(ctx, element)
		position_flow_children(element)
		position_anchored_children(element)

		// Recursive step
		for child in element.children {
			calculate_positions_and_alignment(ctx, child, dt)
		}
	}
}

// Helper to get an element in element cache by key.
// The returned UI_Element will be a copy of the one in the element cache.
@(require_results)
get_element_by_key :: proc(ctx: ^Context, key: UI_Key) -> (element: UI_Element, ok: bool) {
	element_ptr, found := ctx.element_cache[key]
	if found {
		element = element_ptr^
		ok = true
	}
	return
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
		log.infof("id: %v, size: %v, pos: %v", root.name, root.size, root.position)

		for child in root.children {
			print_element_hierarchy(child)
		}
	}
}
