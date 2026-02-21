package ui

import "core:fmt"
import "core:math"
import textpkg "text"

import base "../base"

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
		element_equip_text(ctx, element, text)
		close_element(ctx)
	}
}

button :: proc(ctx: ^Context, id, text: string, style: Style = {}) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().button)

	if open_ok {
		element_equip_text(ctx, element, text)
		close_element(ctx)
	}
	append(&ctx.interactive_elements, element)

	return element.last_comm
}

slider :: proc(
	ctx: ^Context,
	id: string,
	value: ^f32,
	min_val, max_val: f32,
	axis: Axis2 = .X,
	style: Style = {},
	thumb_style: Style = {},
) -> Comm {
	is_vert := axis == .Y
	axis_idx := int(axis)

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
	thumb_size_x: f32 = 20.0
	thumb_size_y: f32 = 20.0
	if sizing, ok := resolved_thumb.sizing_x.?; ok {
		thumb_size_x = sizing.value
	}
	if sizing, ok := resolved_thumb.sizing_y.?; ok {
		thumb_size_y = sizing.value
	}
	thumb_size := base.Vec2{thumb_size_x, thumb_size_y}

	// Setup Track style
	track_style := default_theme().slider
	track_style.sizing_x = is_vert ? sizing_fixed(thumb_size.x) : sizing_grow()
	track_style.sizing_y = is_vert ? sizing_grow() : sizing_fixed(thumb_size.y)

	track, ok := open_element(ctx, id, style, track_style)
	if !ok {return {}}

	// Open Thumb & Logic
	thumb, t_ok := open_element(ctx, fmt.tprintf("%s_thumb", id), resolved_thumb)
	if t_ok {

		// Calculate Space
		pad, border := track.config.layout.padding, track.config.layout.border
		start_space := is_vert ? (pad.top + border.top) : (pad.left + border.left)
		end_space := is_vert ? (pad.bottom + border.bottom) : (pad.right + border.right)

		travel_len := track.size[axis_idx] - start_space - end_space - thumb_size[axis_idx]

		// Input Handling
		if (track.last_comm.held || thumb.last_comm.held) && travel_len > 0 {
			mouse_val := f32(ctx.input.mouse_pos[axis_idx])
			mouse_rel := mouse_val - track.position[axis_idx] - start_space

			// Calculate ratio (centering thumb on mouse)
			ratio := (mouse_rel - thumb_size[axis_idx] * 0.5) / travel_len
			value^ = min_val + (math.clamp(ratio, 0, 1) * (max_val - min_val))
		}

		// Visual Positioning
		range := max_val - min_val
		ratio := range != 0 ? math.clamp((value^ - min_val) / range, 0, 1) : 0.0
		offset := ratio * travel_len

		if is_vert {
			thumb.config.layout.relative_position = {-thumb_size.x * 0.5, offset}
		} else {
			thumb.config.layout.relative_position = {offset, -thumb_size.y * 0.5}
		}

		// Merge interaction states
		track.last_comm.held |= thumb.last_comm.held
		track.last_comm.clicked |= thumb.last_comm.clicked
		track.last_comm.active |= thumb.last_comm.active
		track.last_comm.hovering |= thumb.last_comm.hovering

		append(&ctx.interactive_elements, thumb)
		close_element(ctx)
	}

	append(&ctx.interactive_elements, track)
	close_element(ctx)

	return track.last_comm
}

scrollbar :: proc(
	ctx: ^Context,
	id: string,
	target_id: string,
	axis: Axis2 = .Y,
	style: Style = {},
) {
	target := find_element_by_id(ctx, target_id)
	if target == nil {
		return
	}

	epsilon: f32 = 0.001

	// Auto hide check
	if target.scroll_region.max_offset[axis] <= (1.0 + epsilon) {
		return
	}

	// Calculate thumb size
	viewport_len := target.size[axis]
	content_len := target.scroll_region.content_size[axis]

	if content_len <= (0 + epsilon) {
		return
	}

	view_ratio := viewport_len / content_len

	calculated_thumb_size := max(20.0, viewport_len * view_ratio)

	// Configure slider
	val := &target.scroll_region.offset[axis]

	// Safety clamp
	val^ = clamp(val^, 0, target.scroll_region.max_offset[axis])

	// Merge user style with default transparent background
	sb_style := style
	if sb_style.background_fill.kind == .Not_Set {
		sb_style.background_fill = base.fill_color(0, 0, 0, 0)
	}

	comm := slider(
		ctx,
		id,
		val,
		0,
		target.scroll_region.max_offset[axis],
		axis,
		sb_style,
		Style {
			sizing_x = sizing_fixed(20),
			sizing_y = sizing_fixed(calculated_thumb_size),
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

text_input :: proc(
	ctx: ^Context,
	id: string,
	buf: []u8,
	buf_len: ^int,
	style: Style = {},
) -> Comm {
	element, open_ok := open_element(ctx, id, style, default_theme().text_input)
	if open_ok {

		key := ui_key_hash(element.id_string)
		state, state_exists := &ctx.text_input_states[key]

		if !state_exists {
			new_state := UI_Element_Text_Input_State{}
			new_state.state = textpkg.text_edit_init(ctx.persistent_allocator)

			if buf_len^ > 0 {
				initial_len := min(buf_len^, len(buf))
				textpkg.text_edit_insert(&new_state.state, string(buf[:initial_len]))
			}

			ctx.text_input_states[key] = new_state
			state = &ctx.text_input_states[key]
		}

		buf_len^ = textpkg.text_buffer_copy_into(state.state.buffer, buf)
		text_view := string(buf[:buf_len^])

		element_equip_text(ctx, element, text_view)

		if element == ctx.active_element {
			state.caret_blink_timer += ctx.dt
			CARET_BLINK_PERIOD :: 1.0
			if math.mod(state.caret_blink_timer, CARET_BLINK_PERIOD) < CARET_BLINK_PERIOD / 2 {
				cursor_pos := state.state.selection.active
				text_before_cursor := text_view[:cursor_pos]

				metrics := ctx.measure_text_proc(
					text_before_cursor,
					ctx.font_id,
					ctx.font_user_data,
				)

				line_metrics := ctx.measure_text_proc("", ctx.font_id, ctx.font_user_data)
				caret_x_offset := metrics.width
				caret_height := line_metrics.line_height

				// TODO(Thomas): Caret should be stylable
				CARET_WIDTH :: 2.0
				caret_id := fmt.tprintf("%s_caret", id)

				container(
					ctx,
					caret_id,
					Style {
						sizing_x = sizing_fixed(CARET_WIDTH),
						sizing_y = sizing_fixed(caret_height),
						alignment_x = .Left,
						alignment_y = .Center,
						relative_position = base.Vec2{caret_x_offset, -caret_height / 2},
						background_fill = base.fill(default_color_style[.Text]),
						capability_flags = Capability_Flags{.Background},
					},
				)
			}
		}

		element.last_comm.text = text_view

		close_element(ctx)
	}

	append(&ctx.interactive_elements, element)
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

	append(&ctx.interactive_elements, element)
	return element.last_comm
}
