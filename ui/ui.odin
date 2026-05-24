package ui

import "core:mem"

import "../base"
import textpkg "../text"

ELEMENT_STACK_SIZE :: 64
PARENT_STACK_SIZE :: 64
STYLE_STACK_SIZE :: 64
CHILD_LAYOUT_AXIS_STACK_SIZE :: 64
THEME_STACK_SIZE :: 8

Color_Type :: enum u32 {
	Text,
	Selection_BG,
	Window_BG,
	Hot,
	Active,
	Base,
	Click,
}

Shape_Kind :: enum u8 {
	Checkmark = 1,
}

Render_State :: struct {
	current_clip_rect: base.Rect,
	command_counter:   u64,
	current_z_index:   i32,
}

reset_render_state :: proc(render_state: ^Render_State, window_size: base.Vector2i32) {
	render_state.command_counter = 0
	render_state.current_z_index = 0
	render_state.current_clip_rect = base.Rect{0, 0, window_size.x, window_size.y}
}

push_draw_command :: proc(ctx: ^Context, command: Command, z_offset: i32) {
	ctx.render_state.command_counter += 1

	draw_cmd := Draw_Command {
		z_index   = ctx.render_state.current_z_index + z_offset,
		cmd_idx   = ctx.render_state.command_counter,
		clip_rect = ctx.render_state.current_clip_rect,
		command   = command,
	}
	append(&ctx.command_queue, draw_cmd)
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

Color_Style :: [Color_Type]base.Color

Context :: struct {
	persistent_allocator: mem.Allocator,
	frame_allocator:      mem.Allocator,
	draw_cmd_allocator:   mem.Allocator,
	element_stack:        Stack(^UI_Element, ELEMENT_STACK_SIZE),
	// Style stack for cascading styles. Use push_style/pop_style.
	style_stack:          Stack(Style, STYLE_STACK_SIZE),
	command_queue:        [dynamic]Draw_Command,
	render_state:         Render_State,
	current_parent:       ^UI_Element,
	root_element:         ^UI_Element,
	interaction:          Interaction,
	element_cache:        map[UI_Key]^UI_Element,
	frame_idx:            u64,
	dt:                   f32,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:            f32,
	font_id:              textpkg.Font_Handle,
	window_size:          [2]i32,
	// Theme support
	theme:                Theme,
	theme_stack:          Stack(Theme, THEME_STACK_SIZE),
}

Capability :: enum {
	Background,
	Text,
	Image,
	Shape,
	Active_Animation,
	Hot_Animation,
	Clickable,
	Focusable,
	Scrollable,
}

Capability_Flags :: bit_set[Capability]

default_color_style := Color_Style {
	.Text         = {230, 230, 230, 255},
	.Selection_BG = {90, 90, 90, 255},
	.Window_BG    = {50, 50, 50, 255},
	.Hot          = {95, 95, 95, 255},
	.Active       = {115, 115, 115, 255},
	.Base         = {30, 30, 30, 255},
	.Click        = {200, 200, 200, 255},
}

init :: proc(
	ctx: ^Context,
	input: ^base.Input,
	text_measurement: ^textpkg.Text_Measurement,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
	draw_cmd_allocator: mem.Allocator,
	screen_size: [2]i32,
	font_id: textpkg.Font_Handle,
	font_size: f32,
) {
	ctx^ = {} // zero memory
	ctx.interaction = Interaction {
		input            = input,
		text_measurement = text_measurement,
	}
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.draw_cmd_allocator = draw_cmd_allocator
	ctx.window_size = screen_size
	ctx.font_id = font_id
	ctx.font_size = font_size

	ctx.command_queue = make([dynamic]Draw_Command, draw_cmd_allocator)
	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)

	init_interaction(&ctx.interaction, persistent_allocator)

	// Initialize default theme
	ctx.theme = default_theme()
}

window_resize :: proc(ctx: ^Context, window_size: base.Vector2i32) {
	ctx.window_size = window_size
}

// TODO(Thomas): When we figure out a better allocation scheme for persistent stuf
// this can become better / cleaner.
deinit :: proc(ctx: ^Context) {
	delete(ctx.interaction.interactive_elements)

	deinit_interaction(&ctx.interaction)

	free_list := make([dynamic]^UI_Element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	for _, elem in ctx.element_cache {
		if elem != nil {
			append(&free_list, elem)
		}
	}

	free_elements(free_list[:], ctx.persistent_allocator)

	// Delete the cache after we've freed the elements in the free_list
	delete(ctx.element_cache)
}

free_elements :: proc(free_list: []^UI_Element, allocator: mem.Allocator) {
	for elem in free_list {
		if elem.children != nil {
			delete(elem.children)
		}
		delete(elem.id_string)
		free(elem, allocator)
	}
}

begin :: proc(ctx: ^Context) -> bool {
	ctx.frame_idx += 1

	clear_dynamic_array(&ctx.interaction.interactive_elements)
	clear_dynamic_array(&ctx.command_queue)
	free_all(ctx.frame_allocator)
	free_all(ctx.draw_cmd_allocator)

	reset_render_state(&ctx.render_state, ctx.window_size)

	// Open the root element
	_, root_open_ok := open_element(
		ctx,
		"root",
		Style {
			sizing_x = sizing_fixed(f32(ctx.window_size.x)),
			sizing_y = sizing_fixed(f32(ctx.window_size.y)),
			background_fill = base.fill_color(128, 128, 128),
		},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)

	//NOTE(Thomas): Root element size needs to be updated every frame, meaning not cached like other elements.
	// TODO(Thomas): We can maybe remove this special case by making the root be a NULL key type element, like a spacer.
	if root_element != nil {
		root_element.size.x = f32(ctx.window_size.x)
		root_element.size.y = f32(ctx.window_size.y)
	}

	ctx.root_element = root_element
	return root_open_ok
}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Fit sizing widths
	// 2. Update children cross axis widths
	// 3. Resolve dependent sizes widths
	// 4. Wrap text
	// 5. Fit sizing heights
	// 6. Update chilren cross axis heights
	// 7. Resolve dependent sizes heights
	// 8. Positions
	// 9. Process interactions
	// 10. Draw commands

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Fit sizing widths
	fit_size_axis(ctx.root_element, .X)

	// Update the cross axis size
	size_children_on_cross_axis(ctx.root_element, .X)

	// Resolve dependent widths
	resolve_dependent_sizes_for_axis(ctx.root_element, .X)

	// Wrap text
	wrap_text(ctx, ctx.root_element, ctx.frame_allocator)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Update the cross axis size
	size_children_on_cross_axis(ctx.root_element, .Y)

	// Reolve dependent heights
	resolve_dependent_sizes_for_axis(ctx.root_element, .Y)

	calculate_positions_and_alignment(ctx.root_element, ctx.dt)

	process_input(&ctx.interaction, ctx.root_element, ctx.dt, ctx.frame_allocator)

	draw_all_elements(ctx)

	base.clear_input(ctx.interaction.input)

	prune_dead_elements(ctx)

}

// Prunes dead elements from the cache and the hierarchy
// Dead elements are elements which hasn't been had their last_frame_idx
// update in the last frame.
prune_dead_elements :: proc(ctx: ^Context) {
	Elem :: struct {
		key:   UI_Key,
		value: ^UI_Element,
	}

	// Cannot alter map while iterating, so we make a free list
	free_list := make([dynamic]Elem, context.temp_allocator)
	defer free_all(context.temp_allocator)
	for key, elem in ctx.element_cache {
		if elem != nil {
			if elem.last_frame_idx < ctx.frame_idx - 1 {
				append(&free_list, Elem{key, elem})
			}
		}
	}

	for elem in free_list {
		delete_key(&ctx.element_cache, elem.key)
		if elem.value != nil {
			if elem.value.children != nil {
				delete(elem.value.children)
			}
			delete(elem.value.id_string)
			free(elem.value, ctx.persistent_allocator)
		}
	}
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	if element == nil {
		return
	}

	// NOTE(Thomas): Store the previous clip to restore it after processing this element
	// and its children
	prev_clip_rect := ctx.render_state.current_clip_rect

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

		ctx.render_state.current_clip_rect = base.intersect_rects(prev_clip_rect, new_constraint)
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

		if .Clickable in cap_flags {
			if last_comm.held {
				color = default_color_style[.Click]
			}
		}
		final_bg_fill = color
	case base.Gradient:
		gradient := fill

		if .Hot_Animation in cap_flags {
			hot_color := default_color_style[.Hot]
			gradient.color_start = base.lerp_color(gradient.color_start, hot_color, element.hot)
			gradient.color_end = base.lerp_color(gradient.color_end, hot_color, element.hot)
		}

		if .Active_Animation in cap_flags {
			active_color := default_color_style[.Active]
			gradient.color_start = base.lerp_color(
				gradient.color_start,
				active_color,
				element.active,
			)
			gradient.color_end = base.lerp_color(gradient.color_end, active_color, element.active)
		}

		if .Clickable in cap_flags {
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
			ctx,
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
			z_offset = 0,
		)
	}

	if .Image in cap_flags {
		if texture_id, has_texture := element.config.content.texture_id.?; has_texture {
			draw_image(
				ctx,
				element.position.x,
				element.position.y,
				element.size.x,
				element.size.y,
				texture_id,
				// Base layer
				z_offset = 0,
			)
		}
	}

	if .Text in cap_flags {
		padding := element.config.layout.padding
		content_area_x := element.position.x + padding.left
		content_area_y := element.position.y + padding.top
		content_area_w := element.size.x - padding.left - padding.right
		content_area_h := element.size.y - padding.top - padding.bottom

		text_layout := element.config.content.text_data.text_layout

		// Calculate the initial vertical offset for the whole block based on Aligment_Y
		start_y: f32 = content_area_y
		switch element.config.layout.text_alignment_y {
		case .Top:
			// Default, no change
			start_y = content_area_y
		case .Center:
			start_y = content_area_y + (content_area_h - text_layout.size.y) / 2
		case .Bottom:
			start_y = content_area_y + (content_area_h - text_layout.size.y)
		}

		// Iterate through each line and draw it with the correct X and Y
		current_y := start_y

		for row in text_layout.rows {
			start_x: f32 = content_area_x
			switch element.config.layout.text_alignment_x {
			case .Left:
				// Default, no change
				start_x = content_area_x
			case .Center:
				start_x = content_area_x + (content_area_w - row.size.x) / 2
			case .Right:
				start_x = content_area_x + (content_area_w - row.size.x)
			}

			draw_text(
				ctx,
				start_x,
				current_y,
				text_layout.glyphs[row.glyph_range.start:row.glyph_range.end],
				element.config.text_fill,
				z_offset = 0,
			)
			current_y += row.size.y
		}
	}

	if .Shape in cap_flags {
		draw_shape(
			ctx,
			base.Rect {
				i32(element.position.x),
				i32(element.position.y),
				i32(element.size.x),
				i32(element.size.y),
			},
			element.config.content.shape_data,
			z_offset = 0,
		)
	}

	epsilon: f32 = 0.001
	border := element.config.layout.border
	border_sum := border.left + border.right + border.top + border.bottom
	if .Background in cap_flags && border_sum > (0 + epsilon) {
		draw_rect(
			ctx,
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
			z_offset = 1,
		)
	}

	for child in element.children {
		draw_element(ctx, child)
	}

	ctx.render_state.current_clip_rect = prev_clip_rect
}

draw_all_elements :: proc(ctx: ^Context) {
	draw_element(ctx, ctx.root_element)
}

draw_rect :: proc(
	ctx: ^Context,
	rect: base.Rect,
	fill: base.Fill,
	border_radius: base.Vec4,
	border: Border,
	border_fill: base.Fill,
	z_offset: i32 = 0,
) {
	cmd := Command_Rect{rect, fill, border_fill, border, border_radius}
	push_draw_command(ctx, cmd, z_offset)
}

draw_text :: proc(
	ctx: ^Context,
	x, y: f32,
	glyphs: []textpkg.Glyph,
	color: base.Fill,
	z_offset: i32 = 0,
) {
	cmd := Command_Text{x, y, glyphs, color}
	push_draw_command(ctx, cmd, z_offset)
}

draw_image :: proc(ctx: ^Context, x, y, w, h: f32, texture_id: Texture_Id, z_offset: i32 = 0) {
	cmd := Command_Image{x, y, w, h, texture_id}
	push_draw_command(ctx, cmd, z_offset)
}

draw_shape :: proc(ctx: ^Context, rect: base.Rect, data: Shape_Data, z_offset: i32 = 0) {
	cmd := Command_Shape{rect, data}
	push_draw_command(ctx, cmd, z_offset)
}

set_theme :: proc(ctx: ^Context, theme: Theme) {
	ctx.theme = theme
}

get_theme :: proc(ctx: ^Context) -> Theme {
	return ctx.theme
}

push_theme :: proc(ctx: ^Context, theme: Theme) -> bool {
	if push(&ctx.theme_stack, ctx.theme) {
		ctx.theme = theme
		return true
	}
	return false
}

pop_theme :: proc(ctx: ^Context) -> bool {
	if theme, ok := pop(&ctx.theme_stack); ok {
		ctx.theme = theme
		return true
	}
	return false
}
