package ui

import "core:fmt"
import "core:log"
import "core:math"

import base "../base"
import textpkg "../text"
import fixed_buffer "../text/fixed_buffer"

spacer :: proc(ctx: ^Context, style: Style = {}, name: string = "") {
	key := ui_key_null()
	_ = open_element(ctx, key, style, default_theme().spacer, name = name)
	close_element(ctx)
}

text :: proc(
	ctx: ^Context,
	text: string,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) {
	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, default_theme().text, name = name)
	element_equip_text(ctx, element, text)

	if .Selectable in element.config.capability_flags {
		// TODO(Thomas): Think about whether changing the capabilities
		// like a side-effect here is good, or if we just assert / log instead?
		// Selection needs to be able to click and take focuse for hit testing
		element.config.capability_flags |= {.Clickable, .Focusable}
		textpkg.text_read_only_set_text(&element.text_state, text)
	}

	close_element(ctx)
}

button :: proc(
	ctx: ^Context,
	text: string,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, default_theme().button, name = name)
	element_equip_text(ctx, element, text)
	close_element(ctx)

	return element.last_comm
}

slider :: proc(
	ctx: ^Context,
	value: ^f32,
	min_val, max_val: f32,
	axis: base.Axis2 = .X,
	style: Style = {},
	thumb_style: Style = {},
	track_name: string = "",
	thumb_name: string = "",
	id: string = "",
	loc := #caller_location,
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

	track_key := ui_key(ctx, id, loc)
	track := open_element(ctx, track_key, style, track_style, name = track_name)
	slider_comm := track.last_comm

	// Make thumb
	thumb_key := ui_key_current_loc(track_key.hash)
	thumb := open_element(ctx, thumb_key, resolved_thumb, name = thumb_name)

	inset := content_inset(track.config.layout)

	start_space := is_vert ? inset.top : inset.left
	end_space := is_vert ? inset.bottom : inset.right

	travel_len := track.size[axis] - start_space - end_space - thumb_size[axis]

	range := max_val - min_val
	if (track.last_comm.clicked || thumb.last_comm.held) && travel_len > 0 {
		mouse_val := f32(ctx.interaction.input.mouse_pos[axis])
		mouse_rel := mouse_val - track.position[axis] - start_space

		// Calculate ratio (centering thumb on mouse)
		ratio := (mouse_rel - thumb_size[axis] * 0.5) / travel_len
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
	target: ^UI_Element,
	axis: base.Axis2 = .Y,
	style: Style = {},
	name: string = "",
	id: string = "",
	thickness: f32 = 20,
	loc := #caller_location,
) -> Comm {
	comm := Comm{}

	if target != nil &&
	   target.scroll_region.max_offset[axis] > 1.0 + EPSILON &&
	   target.scroll_region.content_size[axis] > EPSILON {

		scroll := &target.scroll_region
		viewport_len := target.size[axis]
		content_len := scroll.content_size[axis]
		max_offset := scroll.max_offset[axis]

		offset := &scroll.offset[axis]
		offset^ = clamp(offset^, 0, max_offset)

		view_ratio := viewport_len / content_len
		thumb_length := max(20.0, viewport_len * view_ratio)

		thumb_size := base.Vec2{thickness, thickness}
		thumb_size[axis] = thumb_length

		thumb_radius := min(thumb_size.x, thumb_size.y) * 0.5

		track_style := merge_styles(default_theme().scrollbar, style)

		if mode, ok := track_style.position_mode.?; ok && mode == .Anchored {
			if axis == .Y {
				track_style.sizing_y = sizing_percent(1.0)
				if track_style.alignment_x == nil {
					track_style.alignment_x = .Right
				}
			} else {
				track_style.sizing_x = sizing_percent(1.0)
				if track_style.alignment_y == nil {
					track_style.alignment_y = .Bottom
				}
			}
		}

		thumb_style := Style {
			sizing_x        = sizing_fixed(thumb_size.x),
			sizing_y        = sizing_fixed(thumb_size.y),
			background_fill = base.fill_color(80, 80, 80),
			border_fill     = base.TRANSPARENT,
			border_radius   = border_radius_all(thumb_radius),
		}

		comm = slider(
			ctx,
			offset,
			0,
			max_offset,
			axis,
			track_style,
			thumb_style,
			track_name = name,
			thumb_name = fmt.tprintf("%s_thumb", name),
			id = id,
			loc = loc,
		)

		// Sync the target_offset if the user is interacting with the scrollbar.
		// This prevents the layout animation from pulling the view back to the old position.
		if comm.held || comm.clicked {
			scroll.target_offset[axis] = offset^
		}
	}

	return comm
}

text_input :: proc(
	ctx: ^Context,
	buf: []u8,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {

	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, default_theme().text_input, name = name)

	state := &element.text_state
	if state.variant == nil {
		state.variant = textpkg.Text_Edit_State {
			buffer = textpkg.Text_Buffer{buf = fixed_buffer.Fixed_Buffer{buf = buf}},
		}
	}

	edit, is_editable := &state.variant.(textpkg.Text_Edit_State)
	assert(is_editable, "element change text state kind")

	//NOTE(Thomas): We don't need to free this because it's allocated using the frame allocator
	// which will free at the beginning of the next frame.
	text_view, text_alloc_err := textpkg.text_buffer_text(edit.buffer, ctx.frame_allocator)
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
		element.config.layout.font_id,
	)

	caret_x_offset := intrinsic_size.x

	start := element.scroll_region.offset.x
	end := start + content_box(element^).size.x

	if caret_x_offset > end {
		diff := caret_x_offset - end
		element.scroll_region.offset.x += diff
		element.scroll_region.target_offset.x += diff
	} else if caret_x_offset < start {
		diff := start - caret_x_offset
		element.scroll_region.offset.x -= diff
		element.scroll_region.target_offset.x -= diff
	}

	element.last_comm.text = text_view
	close_element(ctx)

	return element.last_comm
}

// TODO(Thomas): Should the .Shape capability always be added
// but whether it's visible is set through alpha value?
// Phase in/out animation?
checkbox :: proc(
	ctx: ^Context,
	checked: ^bool,
	shape_data: Shape_Data,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {

	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, default_theme().checkbox, name = name)

	if element.last_comm.clicked {
		checked^ = !checked^
	}

	if checked^ {
		element_equip_shape(element, shape_data)
	}

	close_element(ctx)

	return element.last_comm
}

image :: proc(
	ctx: ^Context,
	texture_id: Texture_Id,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm {
	key := ui_key(ctx, id, loc)
	element := open_element(ctx, key, style, default_theme().image, name = name)
	element_equip_image(element, texture_id)
	close_element(ctx)

	return element.last_comm
}
