package ui

import "core:container/queue"
import "core:log"
import "core:math"
import "core:mem"
import textpkg "text"

import base "../base"

ELEMENT_STACK_SIZE :: #config(SUI_ELEMENT_STACK_SIZE, 64)
PARENT_STACK_SIZE :: #config(SUI_PARENT_STACK_SIZE, 64)
STYLE_STACK_SIZE :: #config(SUI_STYLE_STACK_SIZE, 64)
CHILD_LAYOUT_AXIS_STACK_SIZE :: #config(SUI_CHILD_LAYOUT_AXIS_STACK_SIZE, 64)

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

@(private)
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
	x, y: f32,
	str:  string,
	fill: base.Fill,
}

Command_Image :: struct {
	x, y, w, h: f32,
	data:       rawptr,
}

Command_Shape :: struct {
	rect: base.Rect,
	data: Shape_Data,
}

Color_Style :: [Color_Type]base.Color

// Font-agnostic text measurement result
Text_Metrics :: struct {
	width:       f32,
	ascent:      f32,
	descent:     f32,
	line_height: f32,
}

// Font-agnostic glyph metrics
Glyph_Metrics :: struct {
	width:        f32,
	left_bearing: f32,
}

// Function pointer types for text measurement
Measure_Text_Proc :: proc(text: string, font_id: u16, user_data: rawptr) -> Text_Metrics

// Function pointer for glyph measurement
Measure_Glyph_Proc :: proc(codepoint: rune, font_id: u16, user_data: rawptr) -> Glyph_Metrics

UI_Element_Text_Input_State :: struct {
	state:             textpkg.Text_Edit_State,
	caret_blink_timer: f32,
}

THEME_STACK_SIZE :: #config(SUI_THEME_STACK_SIZE, 8)

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
	// input is owned by app
	input:                ^base.Input,
	element_cache:        map[UI_Key]^UI_Element,
	text_input_states:    map[UI_Key]UI_Element_Text_Input_State,
	interactive_elements: [dynamic]^UI_Element,
	measure_text_proc:    Measure_Text_Proc,
	measure_glyph_proc:   Measure_Glyph_Proc,
	font_user_data:       rawptr,
	frame_idx:            u64,
	dt:                   f32,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:            f32,
	font_id:              u16,
	window_size:          [2]i32,
	active_element:       ^UI_Element,
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

Comm :: struct {
	element:  ^UI_Element,
	active:   bool,
	hot:      bool,
	clicked:  bool,
	held:     bool,
	hovering: bool,
	text:     string,
}

set_text_measurement_callbacks :: proc(
	ctx: ^Context,
	measure_text: Measure_Text_Proc,
	measure_glyph: Measure_Glyph_Proc,
	user_data: rawptr,
) {
	ctx.measure_text_proc = measure_text
	ctx.measure_glyph_proc = measure_glyph
	ctx.font_user_data = user_data
}

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
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
	draw_cmd_allocator: mem.Allocator,
	screen_size: [2]i32,
	font_id: u16,
	font_size: f32,
) {
	ctx^ = {} // zero memory
	ctx.input = input
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.draw_cmd_allocator = draw_cmd_allocator
	ctx.window_size = screen_size
	ctx.font_id = font_id
	ctx.font_size = font_size

	ctx.command_queue = make([dynamic]Draw_Command, draw_cmd_allocator)
	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)
	ctx.text_input_states = make(map[UI_Key]UI_Element_Text_Input_State, persistent_allocator)
	ctx.interactive_elements = make([dynamic]^UI_Element, persistent_allocator)

	// Initialize default theme
	ctx.theme = default_theme()
}

window_resize :: proc(ctx: ^Context, window_size: base.Vector2i32) {
	ctx.window_size = window_size
}

set_ctx_font_size :: proc(ctx: ^Context, font_size: f32) {
	ctx.font_size = font_size
}

set_ctx_font_id :: proc(ctx: ^Context, font_id: u16) {
	ctx.font_id = font_id
}

// TODO(Thomas): When we figure out a better allocation scheme for persistent stuf
// this can become better / cleaner.
deinit :: proc(ctx: ^Context) {
	delete(ctx.interactive_elements)
	delete(ctx.text_input_states)

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

	clear_dynamic_array(&ctx.interactive_elements)
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

	process_interactions(ctx)

	draw_all_elements(ctx)

	base.clear_input(ctx.input)

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

// Traverses the element hierarchy in BFS order and appends on the elements
// that intersects with the given position.
find_intersections :: proc(
	ctx: ^Context,
	pos: base.Vector2i32,
	elements: ^[dynamic]^UI_Element,
	allocator: mem.Allocator,
) {
	q := queue.Queue(^UI_Element){}
	queue.init(&q, allocator = allocator)
	visited := make(map[string]bool, allocator)

	visited[ctx.root_element.id_string] = true
	ok, alloc_err := queue.push_back(&q, ctx.root_element)
	if alloc_err != .None {
		log.errorf("failed to allocate when push_back onto queue: %v", alloc_err)
	}
	assert(ok)
	assert(alloc_err == .None)

	for queue.len(q) > 0 {
		v := queue.pop_front(&q)

		rect := base.Rect{i32(v.position.x), i32(v.position.y), i32(v.size.x), i32(v.size.y)}

		if base.point_in_rect(pos, rect) {
			append(elements, v)
		}

		for child in v.children {
			_, found := visited[child.id_string]
			if !found {
				visited[child.id_string] = true
				ok, alloc_err = queue.push_back(&q, child)

				if alloc_err != .None {
					log.errorf("failed to allocate when push_back onto queue: %v", alloc_err)
				}

				assert(alloc_err == .None)
				assert(ok)
			}
		}
	}
}

process_interactions :: proc(ctx: ^Context) {
	top_element: ^UI_Element

	intersecting_elements := make([dynamic]^UI_Element, context.temp_allocator)
	defer free_all(context.temp_allocator)
	find_intersections(ctx, ctx.input.mouse_pos, &intersecting_elements, context.temp_allocator)

	#reverse for elem in intersecting_elements {
		if .Clickable in elem.config.capability_flags {
			top_element = elem
			break
		}
	}

	// Clearing the active element when clicking elsewhere
	if base.is_mouse_pressed(ctx.input^, .Left) {
		is_on_active :=
			top_element != nil &&
			ctx.active_element != nil &&
			top_element.id_string == ctx.active_element.id_string
		if !is_on_active {
			ctx.active_element = nil
		}
	}

	// If mouse released and element is not focusable, immediately lose active status
	if base.is_mouse_released(ctx.input^, .Left) {
		if ctx.active_element != nil &&
		   .Focusable not_in ctx.active_element.config.capability_flags {
			ctx.active_element = nil
		}
	}

	// TODO(Thomas): Move this into input module or something?
	SCROLL_SPEED: f32 : 30.0
	// TODO(Thomas): Combine this iteratiion with the one for the .Clickable?
	// TODO(Thomas): Horizontal scrolling (X-direction)?
	#reverse for elem in intersecting_elements {
		if math.abs(ctx.input.scroll_delta.y) > 0 {
			if .Scrollable in elem.config.capability_flags {
				offset_delta := f32(ctx.input.scroll_delta.y) * SCROLL_SPEED

				elem.scroll_region.target_offset.y -= offset_delta

				// NOTE(Thomas) Clamp immediately. This is necessary for input responsiveness.
				// Imagine the case where input goes to -1000, of not clamped to 0,
				// then scrolling in the positive direction will feel sluggish.
				elem.scroll_region.target_offset.y = math.clamp(
					elem.scroll_region.target_offset.y,
					0,
					elem.scroll_region.max_offset.y,
				)

				break
			}
		}
	}

	for element in ctx.interactive_elements {
		comm := Comm {
			element = element,
		}

		is_top_element := (top_element != nil && top_element.id_string == element.id_string)
		is_active_element :=
			(ctx.active_element != nil && ctx.active_element.id_string == element.id_string)

		button_animation_rate_of_change := (1.0 / 0.2) * ctx.dt

		// Handle hover state
		if is_top_element || is_active_element {
			element.hot += button_animation_rate_of_change
			comm.hovering = true
		} else {
			element.hot -= button_animation_rate_of_change
		}

		// Handle active state
		if is_active_element {
			if base.is_mouse_down(ctx.input^, .Left) {
				comm.held = true
			}
		} else if is_top_element {
			// Set new active element
			if base.is_mouse_pressed(ctx.input^, .Left) {
				if .Focusable in element.config.capability_flags {
					ctx.active_element = element
				}
				comm.clicked = true
				comm.held = true
				element.active = 1.0
			}
		}

		if !comm.held {
			element.active -= button_animation_rate_of_change
		}

		// Clamp animations and set final comm state
		element.hot = math.clamp(element.hot, 0, 1)

		if base.approx_equal(element.active, 1.0, 0.001) {
			comm.active = true
		}

		if base.approx_equal(element.hot, 1.0, 0.001) {
			comm.hot = true
		}

		// Text edit
		if is_active_element {
			key := ui_key_hash(ctx.active_element.id_string)
			state, state_ok := &ctx.text_input_states[key]

			if state_ok {
				if ctx.input.text_input.len > 0 {
					text := string(ctx.input.text_input.data[:ctx.input.text_input.len])
					textpkg.text_edit_insert(&state.state, text)
				}

				if base.is_key_pressed(ctx.input^, .Backspace) {
					translation: textpkg.Translation
					if base.is_key_down(ctx.input^, .Left_Shift) {
						translation = textpkg.Translation.Prev_Word
					} else {
						translation = textpkg.Translation.Left
					}
					textpkg.text_edit_delete_to(&state.state, translation)
				} else if base.is_key_pressed(ctx.input^, .Left) {
					translation: textpkg.Translation
					if base.is_key_down(ctx.input^, .Left_Shift) {
						translation = textpkg.Translation.Prev_Word
					} else {
						translation = textpkg.Translation.Left
					}

					textpkg.text_edit_move_to(&state.state, translation)

				} else if base.is_key_pressed(ctx.input^, .Right) {
					translation: textpkg.Translation
					if base.is_key_down(ctx.input^, .Left_Shift) {
						translation = textpkg.Translation.Next_Word
					} else {
						translation = textpkg.Translation.Right
					}
					textpkg.text_edit_move_to(&state.state, translation)
				} else if base.is_key_pressed(ctx.input^, .Tab) {
					textpkg.text_edit_insert(&state.state, "\t")
				}
			}
		}

		element.last_comm = comm
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
	switch final_bg_fill.kind {
	case .Solid:
		color := final_bg_fill.color
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
		final_bg_fill = base.fill(color)

	case .Gradient:
		gradient := final_bg_fill.gradient

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
				final_bg_fill = base.fill(click_color)
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

	case .Not_Set, .None:
	// No fill, nothing to do
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
		draw_image(
			ctx,
			element.position.x,
			element.position.y,
			element.size.x,
			element.size.y,
			element.config.content.image_data,
			// Base layer
			z_offset = 0,
		)
	}

	if .Text in cap_flags {
		padding := element.config.layout.padding
		content_area_x := element.position.x + padding.left
		content_area_y := element.position.y + padding.top
		content_area_w := element.size.x - padding.left - padding.right
		content_area_h := element.size.y - padding.top - padding.bottom

		// Calculate the total height of the entire text block
		total_text_height: f32 = 0
		for line in element.config.content.text_data.lines {
			total_text_height += line.height
		}

		// Calculate the initial vertical offset for the whole block based on Aligment_Y
		start_y: f32 = content_area_y
		switch element.config.layout.text_alignment_y {
		case .Top:
			// Default, no change
			start_y = content_area_y
		case .Center:
			start_y = content_area_y + (content_area_h - total_text_height) / 2
		case .Bottom:
			start_y = content_area_y + (content_area_h - total_text_height)
		}

		// Iterate through each line and draw it with the correct X and Y
		current_y := start_y

		for line in element.config.content.text_data.lines {
			start_x: f32 = content_area_x
			switch element.config.layout.text_alignment_x {
			case .Left:
				// Default, no change
				start_x = content_area_x
			case .Center:
				start_x = content_area_x + (content_area_w - line.width) / 2
			case .Right:
				start_x = content_area_x + (content_area_w - line.width)
			}

			draw_text(ctx, start_x, current_y, line.text, element.config.text_fill, z_offset = 0)
			current_y += line.height
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

draw_text :: proc(ctx: ^Context, x, y: f32, str: string, color: base.Fill, z_offset: i32 = 0) {
	cmd := Command_Text{x, y, str, color}
	push_draw_command(ctx, cmd, z_offset)
}

draw_image :: proc(ctx: ^Context, x, y, w, h: f32, data: rawptr, z_offset: i32 = 0) {
	cmd := Command_Image{x, y, w, h, data}
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
