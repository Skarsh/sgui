package ui

import "core:fmt"
import "core:log"
import "core:math"

import base "../base"
import textpkg "../text"
import fixed_buffer "../text/fixed_buffer"

spacer :: proc(ctx: ^Context, id: string = "", style: Style = {}) {
	_, open_ok := open_element(ctx, id, style, default_theme().spacer)

	assert(open_ok)

	if open_ok {
		close_element(ctx)
	}
}

text :: proc(ctx: ^Context, id, text: string, style: Style = {}) {
	element, open_ok := open_element(ctx, id, style, default_theme().text)
	assert(open_ok)

	if open_ok {
		equip_alloc_err := element_equip_text(ctx, element, text)
		assert(equip_alloc_err == .None)
		close_element(ctx)
	}
}

button :: proc(ctx: ^Context, id, text: string, style: Style = {}) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().button)
	assert(open_ok)

	if open_ok {
		equip_alloc_err := element_equip_text(ctx, element, text)
		assert(equip_alloc_err == .None)
		close_element(ctx)
	}

	return element.last_comm
}

slider :: proc(
	ctx: ^Context,
	id: string,
	value: ^f32,
	min_val, max_val: f32,
	axis: base.Axis2 = .X,
	style: Style = {},
	thumb_style: Style = {},
) -> Comm {

	is_vert := axis == .Y

	// Merge user thumb_style with theme default
	resolved_thumb := merge_styles(default_theme().slider_thumb, thumb_style)

	// Set axis-dependent alignment if not explicitly set by user
	if resolved_thumb.alignment_x == nil {
		resolved_thumb.alignment_x = is_vert ? .Center : .Left
	}

	if resolved_thumb.alignment_y == nil {
		resolved_thumb.alignment_y = is_vert ? .Top : .Center
	}

	// Extract thumb size from resolved style
	thumb_size := base.Vec2{20, 20}
	if sizing, ok := resolved_thumb.sizing_x.?; ok {
		thumb_size.x = sizing.value
	}
	if sizing, ok := resolved_thumb.sizing_y.?; ok {
		thumb_size.y = sizing.value
	}

	// Setup Track style
	track_style := default_theme().slider
	track_style.sizing_x = is_vert ? sizing_fixed(thumb_size.x) : sizing_grow()
	track_style.sizing_y = is_vert ? sizing_grow() : sizing_fixed(thumb_size.y)

	track, track_ok := open_element(ctx, id, style, track_style)
	slider_comm := track.last_comm
	if track_ok {

		// Make thumb
		thumb, thumb_ok := open_element(
			ctx,
			fmt.aprintf("%s_thumb", id, allocator = ctx.frame_allocator),
			resolved_thumb,
		)
		if thumb_ok {

			padding := track.config.layout.padding
			border := track.config.layout.border

			start_space := is_vert ? (padding.top + border.top) : (padding.left + border.left)
			end_space :=
				is_vert ? (padding.bottom + border.bottom) : (padding.right + border.right)

			axis_idx := int(axis)
			travel_len := track.size[axis_idx] - start_space - end_space - thumb_size[axis_idx]

			range := max_val - min_val
			if (track.last_comm.clicked || thumb.last_comm.held) && travel_len > 0 {
				mouse_val := f32(ctx.interaction.input.mouse_pos[axis_idx])
				mouse_rel := mouse_val - track.position[axis_idx] - start_space

				// Calculate ratio (centering thumb on mouse)
				ratio := (mouse_rel - thumb_size[axis_idx] * 0.5) / travel_len
				value^ = min_val + (math.clamp(ratio, 0, 1) * range)
			}

			// Visual Positioning
			ratio := range != 0 ? math.clamp((value^ - min_val) / range, 0, 1) : 0.0
			offset := ratio * travel_len

			if is_vert {
				thumb.config.layout.relative_position = {0, offset}
			} else {
				thumb.config.layout.relative_position = {offset, 0}
			}

			slider_comm.held |= thumb.last_comm.held
			slider_comm.clicked |= thumb.last_comm.clicked
			slider_comm.active |= thumb.last_comm.active
			slider_comm.hovering |= thumb.last_comm.hovering

			close_element(ctx)
		}

		close_element(ctx)
	}

	return slider_comm
}

scrollbar :: proc(
	ctx: ^Context,
	id: string,
	target_id: string,
	axis: base.Axis2 = .Y,
	style: Style = {},
) -> Comm {
	target, target_ok := get_element_pointer_by_string_id(ctx, target_id)
	assert(target_ok)

	comm := Comm{}

	if target_ok {

		axis_sizes: [2]f32
		cross_axis: base.Axis2

		if axis == .X {
			cross_axis = .Y
		} else {
			cross_axis = .X
		}

		axis_sizes[cross_axis] = 20

		epsilon: f32 = 0.001

		// Auto hide check
		if target.scroll_region.max_offset[axis] > (1.0 + epsilon) {

			// Calculate thumb size
			viewport_len := target.size[axis]
			content_len := target.scroll_region.content_size[axis]

			if content_len > (0 + epsilon) {

				view_ratio := viewport_len / content_len

				calculated_thumb_size := max(20.0, viewport_len * view_ratio)
				axis_sizes[axis] = calculated_thumb_size

				// Configure slider
				val := &target.scroll_region.offset[axis]

				// Safety clamp
				val^ = clamp(val^, 0, target.scroll_region.max_offset[axis])

				// Apply theme defaults, then overlay axis-dependent sizing and alignment.
				sb_style := merge_styles(default_theme().scrollbar, style)
				if mode, ok := sb_style.position_mode.?; ok && mode == .Anchored {
					if axis == .Y {
						sb_style.sizing_y = sizing_percent(1.0)
						if sb_style.alignment_x == nil {
							sb_style.alignment_x = .Right
						}
					} else {
						sb_style.sizing_x = sizing_percent(1.0)
						if sb_style.alignment_y == nil {
							sb_style.alignment_y = .Bottom
						}
					}
				}

				comm = slider(
					ctx,
					id,
					val,
					0,
					target.scroll_region.max_offset[axis],
					axis,
					sb_style,
					Style {
						sizing_x = sizing_fixed(axis_sizes[base.Axis2.X]),
						sizing_y = sizing_fixed(axis_sizes[base.Axis2.Y]),
						background_fill = base.fill_color(80, 80, 80),
						border_fill = base.fill_color(0, 0, 0, 0),
					},
				)

				// Sync the target_offset if the user is interacting with the scrollbar.
				// This prevents the layout animation from pulling the view back to the old position.
				if comm.held || comm.clicked {
					target.scroll_region.target_offset[axis] = val^
				}
			}
		}
	}

	return comm
}

// Issue found with text_layout when doing selection rects:
// The text_layout from the previous frame gets deallocated due to frame_allocator
// being used in the text_layout pass. Potenatially two questions we need to answer:
// 1. Can we use the Text_Layout produced from the text_layout pass element_equip_text?
// This could maybe work because text_input does not require the wrap_text pass to be done?
// Then all we would need is to set the Text_Layout struct produced on the element.
// 2. If it's for some reason not viable to use the Text_Layout from the equip_element_text
// pass, then we need to figure out a way to use the last frames' Text_Layout by allocating
// it in a way that will persist between frames. Then we get the issue of pruning it etc.
// NOTE(Thomas): I think that using the element_equip_text produced Text_Layout is not
// the best option, probably that whole pass is a bad idea, and in the near future we want
// selection to work in a unified way for all text that is supposed to be selectable.
text_input :: proc(ctx: ^Context, id: string, buf: []u8, style: Style = {}) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().text_input)

	if open_ok {

		key := element.key
		state, state_exists := &ctx.interaction.text_input_states[key]

		if !state_exists {
			new_state := Text_Input_State{}

			fixed_buf := fixed_buffer.Fixed_Buffer {
				buf = buf,
				len = 0,
			}
			text_buffer := textpkg.Text_Buffer {
				buf = fixed_buf,
			}

			textpkg.text_edit_init(&new_state.state, text_buffer)

			ctx.interaction.text_input_states[key] = new_state
			state = &ctx.interaction.text_input_states[key]
		}

		//NOTE(Thomas): We don't need to free this because it's allocated using the frame allocator
		// which will free at the beginning of the next frame.
		text_view, text_alloc_err := textpkg.text_buffer_text(
			state.state.buffer,
			ctx.frame_allocator,
		)
		if text_alloc_err != .None {
			log.error("Error when trying to get text buffer text: ", text_alloc_err)
		}
		assert(text_alloc_err == .None)

		// NOTE(Thomas): We need to store the size from the previous frame so that
		// we have the size of the proper laid out text_input element. After `element_equip_text`
		// runs that will have the size of the text that it equips until the layout passes has
		// been run.
		last_frame_size := element.size

		// TODO(Thomas): Styling should be flexible
		element_equip_text(ctx, element, text_view)

		if element.key == ctx.interaction.focused_id {
			state.caret_blink_timer += ctx.dt
			CARET_BLINK_PERIOD :: 1.0
			CARET_WIDTH :: 2.0

			cursor_pos := state.state.selection.active
			text_before_cursor := text_view[:cursor_pos]

			// TODO(Thomas): HACK - All of this text measurement is very temporary, and should
			// use cached sizes from the text layout system.
			metrics := ctx.interaction.text_measurement.measure_text_proc(
				text_before_cursor,
				ctx.font_id,
				ctx.interaction.text_measurement.font_user_data,
			)
			line_metrics := ctx.interaction.text_measurement.measure_text_proc(
				"",
				ctx.font_id,
				ctx.interaction.text_measurement.font_user_data,
			)
			caret_x_offset := metrics.width
			caret_height := line_metrics.line_height

			start := element.scroll_region.offset.x
			padding_sum := get_padding_sum_for_axis(element.config.layout.padding, .X)
			border_sum := get_border_sum_for_axis(element.config.layout.border, .X)
			end := start + (last_frame_size.x - padding_sum - border_sum)

			// TODO(Thomas): What about the width of the caret here?
			if caret_x_offset > end {
				diff := caret_x_offset - end
				element.scroll_region.offset.x += diff
				element.scroll_region.target_offset.x += diff
			} else if caret_x_offset < start {
				diff := start - caret_x_offset
				element.scroll_region.offset.x -= diff
				element.scroll_region.target_offset.x -= diff
			}

			// TODO(Thomas): This way of doing the blinking is really bad.
			if math.mod(state.caret_blink_timer, CARET_BLINK_PERIOD) < CARET_BLINK_PERIOD / 2 {
				// TODO(Thomas): Caret should be stylable
				caret_id := fmt.tprintf("%s_caret", id)

				// Caret container
				container(
					ctx,
					caret_id,
					Style {
						sizing_x = sizing_fixed(CARET_WIDTH),
						sizing_y = sizing_fixed(caret_height),
						alignment_x = .Left,
						alignment_y = .Center,
						relative_position = base.Vec2 {
							caret_x_offset - element.scroll_region.offset.x,
							0,
						},
						background_fill = default_color_style[.Text],
						capability_flags = Capability_Flags{.Background},
						position_mode = .Anchored,
					},
				)
			}

			// Selection
			selection_id := fmt.tprintf("%s_selection", id)
			selection := state.state.selection
			selection_rects := make([dynamic]base.Rect_F32, ctx.frame_allocator)
			rects_alloc_err := textpkg.text_layout_selection_rects(
				element.config.content.text_data.text_layout,
				selection,
				&selection_rects,
			)

			assert(rects_alloc_err == .None)
			assert(len(selection_rects) == 0 || len(selection_rects) == 1)

			if len(selection_rects) == 1 {
				container(
					ctx,
					selection_id,
					Style {
						sizing_x = sizing_fixed(selection_rects[0].w),
						sizing_y = sizing_fixed(caret_height),
						alignment_x = .Left,
						alignment_y = .Center,
						relative_position = base.Vec2 {
							selection_rects[0].x - element.scroll_region.offset.x,
							0,
						},
						background_fill = base.fill_color(255, 255, 255, 128),
						capability_flags = Capability_Flags{.Background},
						position_mode = .Anchored,
					},
				)
			}
		}

		element.last_comm.text = text_view
		close_element(ctx)
	}

	return element.last_comm
}

// TODO(Thomas): Should the .Shape capability always be added
// but whether it's visible is set through alhpa value?
// Phase in/out animation?
checkbox :: proc(
	ctx: ^Context,
	id: string,
	checked: ^bool,
	shape_data: Shape_Data,
	style: Style = {},
) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().checkbox)
	if open_ok {

		if element.last_comm.clicked {
			if checked^ {
				checked^ = false
			} else {
				checked^ = true
			}
		}

		if checked^ {
			element_equip_shape(element, shape_data)
		}

		close_element(ctx)
	}

	return element.last_comm
}

image :: proc(ctx: ^Context, id: string, texture_id: Texture_Id, style: Style = {}) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().image)

	if open_ok {
		element_equip_image(element, texture_id)
		close_element(ctx)
	}

	return element.last_comm
}
