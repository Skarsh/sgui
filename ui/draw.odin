package ui

import "core:fmt"
import "core:math"
import "core:mem"

import "../base"
import textpkg "../text"

Shape_Kind :: enum u8 {
	Checkmark = 1,
}

Draw_State :: struct {
	current_clip_rect: base.Rect,
	command_counter:   u64,
	command_queue:     [dynamic]Draw_Command,
}

@(require_results)
init_draw_state :: proc(draw_state: ^Draw_State, allocator: mem.Allocator) -> mem.Allocator_Error {
	alloc_err: mem.Allocator_Error
	draw_state.command_queue, alloc_err = make([dynamic]Draw_Command, allocator)
	return alloc_err
}

reset_draw_state :: proc(draw_state: ^Draw_State, window_size: base.Vector2i32) {
	draw_state.command_counter = 0
	draw_state.current_clip_rect = base.Rect{0, 0, window_size.x, window_size.y}
	clear_dynamic_array(&draw_state.command_queue)
}

push_draw_command :: proc(draw_state: ^Draw_State, command: Command, z_index: i32) {
	draw_state.command_counter += 1

	draw_cmd := Draw_Command {
		z_index   = z_index,
		cmd_idx   = draw_state.command_counter,
		clip_rect = draw_state.current_clip_rect,
		command   = command,
	}
	_, alloc_err := append(&draw_state.command_queue, draw_cmd)
	assert(
		alloc_err == .None,
		fmt.tprintf("allocation error when appending to draw command queue: %v", alloc_err),
	)
}

Draw_Command :: struct {
	command:   Command,
	clip_rect: base.Rect,
	cmd_idx:   u64,
	z_index:   i32,
}

Command :: union {
	Command_Rect,
	Command_Text,
	Command_Image,
	Command_Shape,
}

Command_Rect :: struct {
	rect:          base.Rect,
	fill:          base.Fill,
	border_fill:   base.Fill,
	border:        Border,
	// Mapping: x=top-left, y=top-right, z=bottom-right, w=bottom-left
	border_radius: base.Vec4,
}

Command_Text :: struct {
	x, y:   f32,
	glyphs: []textpkg.Glyph,
	fill:   base.Fill,
}

Texture_Id :: distinct u64

Command_Image :: struct {
	x, y, w, h: f32,
	texture_id: Texture_Id,
}

Command_Shape :: struct {
	rect: base.Rect,
	data: Shape_Data,
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	draw_state := &ctx.draw_state
	assert(draw_state != nil)
	assert(element != nil)

	if element != nil && draw_state != nil {

		// NOTE(Thomas): Store the previous clip to restore it after processing this element
		// and its children
		prev_clip_rect := draw_state.current_clip_rect

		clip_config := element.config.clip
		should_clip := clip_config.clip_axes.x || clip_config.clip_axes.y

		if should_clip {
			new_constraint := base.Rect {
				x = i32(element.position.x),
				y = i32(element.position.y),
				w = i32(element.size.x),
				h = i32(element.size.y),
			}

			//NOTE(Thomas): If X clipping is disabled, we ignore the elements's width constraint
			// and use the the parent's width constraint instead.
			if !clip_config.clip_axes.x {
				new_constraint.x = prev_clip_rect.x
				new_constraint.w = prev_clip_rect.w
			}

			//NOTE(Thomas): If Y clipping is disabled, we ignore the elements's height constraint
			// and use the the parent's height constraint instead.
			if !clip_config.clip_axes.y {
				new_constraint.y = prev_clip_rect.y
				new_constraint.h = prev_clip_rect.h
			}

			draw_state.current_clip_rect = base.intersect_rects(prev_clip_rect, new_constraint)
		}

		cap_flags := element.config.capability_flags
		final_bg_fill := element.fill

		last_comm := element.last_comm


		// TODO(Thomas): Click could have an embossed / debossed animation effect instead.
		// There's lots left to figure out for hot and active too, it could be highlighted with
		// a border instead or many other things. This is a temporary a solution.
		switch fill in final_bg_fill {
		case base.Color:
			color := fill
			if .Hot_Animation in cap_flags {
				hot_color := default_color_style[.Hot]
				color = base.lerp_color(color, hot_color, element.hot)
			}

			if .Active_Animation in cap_flags {
				active_color := default_color_style[.Active]
				color = base.lerp_color(color, active_color, element.active)
			}

			if .Click_Animation in cap_flags {
				if last_comm.held {
					color = default_color_style[.Click]
				}
			}
			final_bg_fill = color
		case base.Gradient:
			gradient := fill

			if .Hot_Animation in cap_flags {
				hot_color := default_color_style[.Hot]
				gradient.color_start = base.lerp_color(
					gradient.color_start,
					hot_color,
					element.hot,
				)
				gradient.color_end = base.lerp_color(gradient.color_end, hot_color, element.hot)
			}

			if .Active_Animation in cap_flags {
				active_color := default_color_style[.Active]
				gradient.color_start = base.lerp_color(
					gradient.color_start,
					active_color,
					element.active,
				)
				gradient.color_end = base.lerp_color(
					gradient.color_end,
					active_color,
					element.active,
				)
			}

			if .Click_Animation in cap_flags {
				if last_comm.held {
					click_color := default_color_style[.Click]
					final_bg_fill = click_color
				} else {
					final_bg_fill = base.fill_gradient(
						gradient.color_start,
						gradient.color_end,
						gradient.direction,
					)
				}
			} else {
				final_bg_fill = base.fill_gradient(
					gradient.color_start,
					gradient.color_end,
					gradient.direction,
				)
			}
		}

		if .Background in element.config.capability_flags {
			draw_rect(
				draw_state,
				base.Rect {
					i32(element.position.x),
					i32(element.position.y),
					i32(element.size.x),
					i32(element.size.y),
				},
				final_bg_fill,
				element.config.layout.border_radius,
				border = Border{},
				border_fill = base.fill_color(0, 0, 0, 0),
				z_index = 0,
			)
		}

		if .Image in cap_flags {
			if texture_id, has_texture := element.config.content.texture_id.?; has_texture {
				draw_image(
					draw_state,
					element.position.x,
					element.position.y,
					element.size.x,
					element.size.y,
					texture_id,
					// Base layer
					z_index = 0,
				)
			}
		}

		if .Text in cap_flags {
			box := content_box(element^)

			text_layout, found_text_layout := textpkg.read_text_layout_cache(
				ctx.text_system.layout_cache,
				element.key.hash,
			)
			if found_text_layout {
				// Calculate the initial vertical offset for the whole block based on Aligment_Y
				start_pos := content_origin_scrolled(element^)
				switch element.config.layout.text_alignment_y {
				case .Top:
				// Default, no change
				case .Center:
					start_pos.y = start_pos.y + (box.size.y - text_layout.size.y) / 2
				case .Bottom:
					start_pos.y = start_pos.y + (box.size.y - text_layout.size.y)
				}

				// Iterate through each line and draw it with the correct X and Y
				current_y := start_pos.y

				// Get the selection if the current element is focused.
				// We do this outside of the loop because selection doesn't
				// change until new input from the user.
				selection: textpkg.Selection
				has_selection: bool
				is_focused := ctx.interaction.focused_id == element.key
				if is_focused {
					selection, has_selection = get_text_state_selection(&ctx.text_system, element^)
				}

				for row in text_layout.rows {
					// Draw selection
					if has_selection {
						sel_rect := textpkg.text_layout_row_selection_rect(
							text_layout,
							row,
							selection,
						)

						draw_rect(
							draw_state,
							base.Rect {
								x = i32(start_pos.x + sel_rect.x),
								y = i32(start_pos.y + sel_rect.y),
								w = i32(sel_rect.w),
								h = i32(sel_rect.h),
							},
							base.fill_color(255, 255, 255, 128),
							border_radius = base.Vec4{},
							border = Border{},
							border_fill = base.fill_color(0, 0, 0, 0),
							z_index = 0,
						)
					}

					// Draw text
					start_x := start_pos.x + row.pos.x
					draw_text(
						draw_state,
						start_x,
						current_y,
						base.slice_from_range(text_layout.glyphs, row.glyph_range),
						element.config.text_fill,
						z_index = 0,
					)
					current_y += row.size.y
				}

				if has_selection {
					caret_byte_pos, blink_timer, is_focused_edit := focused_caret(
						&ctx.text_system,
						element.key,
					)

					if is_focused_edit {

						// TODO(Thomas): This should be configurable
						CARET_BLINK_PERIOD :: 1.0
						CARET_WIDTH :: 2.0

						//  TODO(Thomas): Bad way of doing this I think
						if math.mod(blink_timer, CARET_BLINK_PERIOD) < CARET_BLINK_PERIOD / 2 {
							caret_pos, caret_height := textpkg.text_layout_caret_pos(
								text_layout,
								caret_byte_pos,
							)

							// TODO(Thomas): HACK - This is a special case for when there
							// is no rows, then the start_pos.y doesn't subtract the size
							// of the text_layout / 2 as far as I can see.
							// This works, but maybe there is a cleaner solution, something
							// like paragraphs always producing one row, even if it's empty??
							if len(text_layout.rows) == 0 {
								caret_height = textpkg.font_line_height(
									&ctx.text_system,
									ctx.font_id,
								)
								caret_pos.y -= caret_height / 2
							}

							draw_rect(
								draw_state,
								base.Rect {
									x = i32(start_pos.x + caret_pos.x),
									y = i32(start_pos.y + caret_pos.y),
									w = i32(CARET_WIDTH),
									h = i32(caret_height),
								},
								element.config.text_fill,
								border_radius = base.Vec4{},
								border = Border{},
								border_fill = base.fill_color(0, 0, 0, 0),
								z_index = 0,
							)
						}
					}
				}
			}
		}

		if .Shape in cap_flags {
			draw_shape(
				draw_state,
				base.Rect {
					i32(element.position.x),
					i32(element.position.y),
					i32(element.size.x),
					i32(element.size.y),
				},
				element.config.content.shape_data,
				z_index = 0,
			)
		}

		epsilon: f32 = 0.001
		border := element.config.layout.border
		border_sum := border.left + border.right + border.top + border.bottom
		if .Background in cap_flags && border_sum > (0 + epsilon) {
			draw_rect(
				draw_state,
				base.Rect {
					i32(element.position.x),
					i32(element.position.y),
					i32(element.size.x),
					i32(element.size.y),
				},
				base.fill_color(0, 0, 0, 0),
				element.config.layout.border_radius,
				element.config.layout.border,
				element.config.border_fill,
				z_index = 1,
			)
		}

		for child in element.children {
			draw_element(ctx, child)
		}

		draw_state.current_clip_rect = prev_clip_rect
	}
}

draw_all_elements :: proc(ctx: ^Context) {
	draw_element(ctx, ctx.root_element)
}

draw_rect :: proc(
	draw_state: ^Draw_State,
	rect: base.Rect,
	fill: base.Fill,
	border_radius: base.Vec4,
	border: Border,
	border_fill: base.Fill,
	z_index: i32 = 0,
) {
	cmd := Command_Rect{rect, fill, border_fill, border, border_radius}
	push_draw_command(draw_state, cmd, z_index)
}

draw_text :: proc(
	draw_state: ^Draw_State,
	x, y: f32,
	glyphs: []textpkg.Glyph,
	color: base.Fill,
	z_index: i32 = 0,
) {
	cmd := Command_Text{x, y, glyphs, color}
	push_draw_command(draw_state, cmd, z_index)
}

draw_image :: proc(
	draw_state: ^Draw_State,
	x, y, w, h: f32,
	texture_id: Texture_Id,
	z_index: i32 = 0,
) {
	cmd := Command_Image{x, y, w, h, texture_id}
	push_draw_command(draw_state, cmd, z_index)
}

draw_shape :: proc(draw_state: ^Draw_State, rect: base.Rect, data: Shape_Data, z_index: i32 = 0) {
	cmd := Command_Shape{rect, data}
	push_draw_command(draw_state, cmd, z_index)
}
