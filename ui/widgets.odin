package ui

import "core:fmt"
import "core:log"
import "core:math"

import base "../base"
import textpkg "../text"
import fixed_buffer "../text/fixed_buffer"

spacer :: proc(ctx: ^Context, id: string = "", style: Style = {}) {
	_ = open_element(ctx, id, style, default_theme().spacer)
	close_element(ctx)
}

text :: proc(ctx: ^Context, id, text: string, style: Style = {}) {
	element := open_element(ctx, id, style, default_theme().text)
	element_equip_text(ctx, element, text)

	if .Selectable in element.config.capability_flags {
		// TODO(Thomas): Think about whether changing the capabilities
		// like a side-effect here is good, or if we just assert / log instead?
		// Selection needs to be able to click and take focuse for hit testing
		element.config.capability_flags |= {.Clickable, .Focusable}

		if element.key == ctx.interaction.focused_id {
			key := element.key
			state, state_exists := &ctx.text_system.text_states[key.hash]

			// TODO(Thomas): Can this be simplified?
			if !state_exists {
				text_read_state := textpkg.Text_Read_Only_State{}
				text_state := textpkg.Text_State {
					variant = text_read_state,
				}
				ctx.text_system.text_states[key.hash] = text_state
				ok: bool
				state, ok = &ctx.text_system.text_states[key.hash]
				assert(ok)
			}

			textpkg.text_read_only_set_text(&state.variant.(textpkg.Text_Read_Only_State), text)
		}
	}

	close_element(ctx)
}

button :: proc(ctx: ^Context, id, text: string, style: Style = {}) -> Comm {
	element := open_element(ctx, id, style, default_theme().button)
	element_equip_text(ctx, element, text)
	close_element(ctx)

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

	track := open_element(ctx, id, style, track_style)
	slider_comm := track.last_comm

	// Make thumb
	thumb := open_element(
		ctx,
		fmt.aprintf("%s_thumb", id, allocator = ctx.frame_allocator),
		resolved_thumb,
	)

	padding := track.config.layout.padding
	border := track.config.layout.border

	start_space := is_vert ? (padding.top + border.top) : (padding.left + border.left)
	end_space := is_vert ? (padding.bottom + border.bottom) : (padding.right + border.right)

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

	close_element(ctx) // thumb

	close_element(ctx) // track

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

text_input :: proc(ctx: ^Context, id: string, buf: []u8, style: Style = {}) -> Comm {
	element := open_element(ctx, id, style, default_theme().text_input)

	key := element.key
	state, state_exists := &ctx.text_system.text_states[key.hash]

	if !state_exists {
		new_state := textpkg.Text_State{}

		fixed_buf := fixed_buffer.Fixed_Buffer {
			buf = buf,
			len = 0,
		}
		text_buffer := textpkg.Text_Buffer {
			buf = fixed_buf,
		}

		text_edit_state := textpkg.Text_Edit_State{}
		textpkg.text_edit_init(&text_edit_state, text_buffer)
		new_state.variant = text_edit_state

		ctx.text_system.text_states[key.hash] = new_state
		state = &ctx.text_system.text_states[key.hash]
	}

	//NOTE(Thomas): We don't need to free this because it's allocated using the frame allocator
	// which will free at the beginning of the next frame.
	text_view, text_alloc_err := textpkg.text_buffer_text(
		state.variant.(textpkg.Text_Edit_State).buffer,
		ctx.frame_allocator,
	)
	if text_alloc_err != .None {
		log.error("Error when trying to get text buffer text: ", text_alloc_err)
	}
	assert(text_alloc_err == .None)

	// TODO(Thomas): Styling should be flexible
	element_equip_text(ctx, element, text_view)

	cursor_pos := state.selection.active
	text_before_cursor := text_view[:cursor_pos]

	intrinsic_size := textpkg.measure_text_intrinsic(
		text_before_cursor,
		&ctx.text_system,
		ctx.font_id,
	)

	caret_x_offset := intrinsic_size.x

	start := element.scroll_region.offset.x
	padding_sum := get_padding_sum_for_axis(element.config.layout.padding, .X)
	border_sum := get_border_sum_for_axis(element.config.layout.border, .X)
	end := start + (element.size.x - padding_sum - border_sum)

	if caret_x_offset > end {
		diff := caret_x_offset - end
		element.scroll_region.offset.x += diff
		element.scroll_region.target_offset.x += diff
	} else if caret_x_offset < start {
		diff := start - caret_x_offset
		element.scroll_region.offset.x -= diff
		element.scroll_region.target_offset.x -= diff
	}


	// TODO(Thomas): The blinker is really a global thing and can live in interaction??
	//if element.key == ctx.interaction.focused_id {
	//state.caret_blink_timer += ctx.dt
	//}

	element.last_comm.text = text_view
	close_element(ctx)

	return element.last_comm
}

// TODO(Thomas): Should the .Shape capability always be added
// but whether it's visible is set through alpha value?
// Phase in/out animation?
checkbox :: proc(
	ctx: ^Context,
	id: string,
	checked: ^bool,
	shape_data: Shape_Data,
	style: Style = {},
) -> Comm {

	element := open_element(ctx, id, style, default_theme().checkbox)

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

	return element.last_comm
}

image :: proc(ctx: ^Context, id: string, texture_id: Texture_Id, style: Style = {}) -> Comm {

	element := open_element(ctx, id, style, default_theme().image)
	element_equip_image(element, texture_id)
	close_element(ctx)

	return element.last_comm
}
