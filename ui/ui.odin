package ui

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:strings"
import textedit "core:text/edit"

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

Command_Push_Scissor :: struct {
	rect: base.Rect,
}

Command_Pop_Scissor :: struct {}

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
	builder:           strings.Builder,
	state:             textedit.State,
	caret_blink_timer: f32,
}

THEME_STACK_SIZE :: #config(SUI_THEME_STACK_SIZE, 8)

Context :: struct {
	persistent_allocator:    mem.Allocator,
	frame_allocator:         mem.Allocator,
	draw_cmd_allocator:      mem.Allocator,
	element_stack:           Stack(^UI_Element, ELEMENT_STACK_SIZE),
	// TODO(Thomas): Style stacks, move them into its own struct?
	// Maybe even do some metaprogramming to generate them if it becomes
	// too many of them?
	sizing_x_stack:          Stack(Sizing, STYLE_STACK_SIZE),
	sizing_y_stack:          Stack(Sizing, STYLE_STACK_SIZE),
	clip_stack:              Stack(Clip_Config, STYLE_STACK_SIZE),
	capability_flags_stack:  Stack(Capability_Flags, STYLE_STACK_SIZE),
	background_fill_stack:   Stack(base.Fill, STYLE_STACK_SIZE),
	text_fill_stack:         Stack(base.Fill, STYLE_STACK_SIZE),
	padding_stack:           Stack(Padding, STYLE_STACK_SIZE),
	margin_stack:            Stack(Margin, STYLE_STACK_SIZE),
	child_gap_stack:         Stack(f32, STYLE_STACK_SIZE),
	layout_mode_stack:       Stack(Layout_Mode, STYLE_STACK_SIZE),
	layout_direction_stack:  Stack(Layout_Direction, STYLE_STACK_SIZE),
	relative_position_stack: Stack(base.Vec2, STYLE_STACK_SIZE),
	alignment_x_stack:       Stack(Alignment_X, STYLE_STACK_SIZE),
	alignment_y_stack:       Stack(Alignment_Y, STYLE_STACK_SIZE),
	text_padding_stack:      Stack(Padding, STYLE_STACK_SIZE),
	text_alignment_x_stack:  Stack(Alignment_X, STYLE_STACK_SIZE),
	text_alignment_y_stack:  Stack(Alignment_Y, STYLE_STACK_SIZE),
	border_radius_stack:     Stack(base.Vec4, STYLE_STACK_SIZE),
	border_stack:            Stack(Border, STYLE_STACK_SIZE),
	border_fill_stack:       Stack(base.Fill, STYLE_STACK_SIZE),
	command_queue:           [dynamic]Draw_Command,
	render_state:            Render_State,
	current_parent:          ^UI_Element,
	root_element:            ^UI_Element,
	input:                   Input,
	element_cache:           map[UI_Key]^UI_Element,
	text_input_states:       map[UI_Key]UI_Element_Text_Input_State,
	interactive_elements:    [dynamic]^UI_Element,
	measure_text_proc:       Measure_Text_Proc,
	measure_glyph_proc:      Measure_Glyph_Proc,
	font_user_data:          rawptr,
	frame_idx:               u64,
	dt:                      f32,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:               f32,
	font_id:                 u16,
	window_size:             [2]i32,
	active_element:          ^UI_Element,
	// Theme support
	theme:                   Theme,
	theme_stack:             Stack(Theme, THEME_STACK_SIZE),
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
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
	draw_cmd_allocator: mem.Allocator,
	screen_size: [2]i32,
	font_id: u16,
	font_size: f32,
) {
	ctx^ = {} // zero memory
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

set_ctx_font_size :: proc(ctx: ^Context, font_size: f32) {
	ctx.font_size = font_size
}

set_ctx_font_id :: proc(ctx: ^Context, font_id: u16) {
	ctx.font_id = font_id
}

deinit :: proc(ctx: ^Context) {
}

begin :: proc(ctx: ^Context) -> bool {
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

	clear_input(ctx)

	ctx.frame_idx += 1
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
	if is_mouse_pressed(ctx^, .Left) {
		is_on_active :=
			top_element != nil &&
			ctx.active_element != nil &&
			top_element.id_string == ctx.active_element.id_string
		if !is_on_active {
			ctx.active_element = nil
		}
	}

	// If mouse released and element is not focusable, immediately lose active status
	if is_mouse_released(ctx^, .Left) {
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
			if is_mouse_down(ctx^, .Left) {
				comm.held = true
			}
		} else if is_top_element {
			// Set new active element
			if is_mouse_pressed(ctx^, .Left) {
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
				if is_key_pressed(ctx^, .Backspace) {
					translation: textedit.Translation
					if is_key_down(ctx^, .Left_Shift) {
						translation = textedit.Translation.Word_Left
					} else {
						translation = textedit.Translation.Left
					}
					textedit.delete_to(&state.state, translation)
				} else if is_key_pressed(ctx^, .Left) {
					translation: textedit.Translation
					if is_key_down(ctx^, .Left_Shift) {
						translation = textedit.Translation.Word_Left
					} else {
						translation = textedit.Translation.Left
					}

					textedit.move_to(&state.state, translation)

				} else if is_key_pressed(ctx^, .Right) {
					translation: textedit.Translation
					if is_key_down(ctx^, .Left_Shift) {
						translation = textedit.Translation.Word_Right
					} else {
						translation = textedit.Translation.Right
					}
					textedit.move_to(&state.state, translation)
				} else if is_key_pressed(ctx^, .Tab) {
					textedit.input_text(&state.state, "\t")
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
		text_padding := element.config.layout.text_padding
		content_area_x := element.position.x + text_padding.left
		content_area_y := element.position.y + text_padding.top
		content_area_w := element.size.x - text_padding.left - text_padding.right
		content_area_h := element.size.y - text_padding.top - text_padding.bottom

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


spacer :: proc(ctx: ^Context, id: string = "", style: Style = {}) {
	default_style := Style {
		sizing_x = sizing_grow(),
		sizing_y = sizing_grow(),
	}

	_, open_ok := open_element(ctx, id, style, default_style)
	assert(open_ok)
	if open_ok {
		close_element(ctx)
	}
}

text :: proc(ctx: ^Context, id, text: string, style: Style = {}) {
	default_style := Style {
		text_padding = Padding{},
		text_alignment_x = .Left,
		text_alignment_y = .Top,
		text_fill = base.fill_color(255, 255, 255),
		clip = Clip_Config{clip_axes = {true, true}},
	}

	element, open_ok := open_element(ctx, id, style, default_style)
	assert(open_ok)
	if open_ok {
		element_equip_text(ctx, element, text)
		close_element(ctx)
	}
}

button :: proc(ctx: ^Context, id, text: string, style: Style = {}) -> Comm {
	default_style := Style {
		sizing_x = sizing_grow(),
		sizing_y = sizing_grow(),
		text_padding = padding_all(10),
		text_alignment_x = .Center,
		background_fill = base.fill_color(24, 24, 24),
		text_fill = base.fill_color(255, 128, 255, 128),
		capability_flags = Capability_Flags{.Background, .Clickable, .Hot_Animation},
		clip = Clip_Config{clip_axes = {true, true}},
	}

	element, open_ok := open_element(ctx, id, style, default_style)

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
	min: f32,
	max: f32,
	axis: Axis2 = .X,
	thumb_size: base.Vec2 = {20, 20},
	thumb_color: base.Fill = {},
	thumb_border_width: Border = {},
	thumb_border_fill_param: base.Fill = {},
	style: Style = {},
) -> Comm {

	default_style: Style
	if axis == .X {
		default_style = Style {
			sizing_x         = sizing_grow(),
			sizing_y         = sizing_fixed(thumb_size.y),
			layout_mode      = .Relative,
			border_radius    = border_radius_all(2),
			background_fill  = base.fill_color(24, 24, 24),
			capability_flags = Capability_Flags {
				.Background,
				.Clickable,
				.Focusable,
				.Hot_Animation,
			},
		}
	} else {
		default_style = Style {
			sizing_x         = sizing_fixed(thumb_size.x),
			sizing_y         = sizing_grow(),
			layout_mode      = .Relative,
			border_radius    = border_radius_all(2),
			background_fill  = base.fill_color(24, 24, 24),
			capability_flags = Capability_Flags {
				.Background,
				.Clickable,
				.Focusable,
				.Hot_Animation,
			},
		}
	}

	element, open_ok := open_element(ctx, id, style, default_style)

	if open_ok {
		padding := element.config.layout.padding
		border := element.config.layout.border
		pad_start, pad_end := get_padding_for_axis(padding, axis)
		border_start, border_end := get_border_for_axis(border, axis)

		track_len := element.size[axis] - pad_start - pad_end - border_start - border_end
		thumb_len := axis == .X ? thumb_size.x : thumb_size.y

		range := max - min

		// Handle input
		if element.last_comm.held && track_len > 0 {
			mouse_val := axis == .X ? f32(ctx.input.mouse_pos.x) : f32(ctx.input.mouse_pos.y)
			element_pos := axis == .X ? element.position.x : element.position.y

			mouse_relative := mouse_val - (element_pos + pad_start)

			new_ratio := math.clamp(mouse_relative / track_len, 0, 1)
			value^ = min + (new_ratio * range)
		}

		ratio: f32 = 0
		if range != 0 {
			ratio = math.clamp((value^ - min) / range, 0, 1)
		}

		thumb_travel := track_len - thumb_len
		thumb_offset := ratio * thumb_travel

		thumb_align_x: Alignment_X
		thumb_align_y: Alignment_Y
		thumb_rel_pos: base.Vec2

		if axis == .X {
			thumb_align_x = .Left
			thumb_align_y = .Center
			thumb_rel_pos = base.Vec2{thumb_offset, -thumb_size.y / 2}
		} else {
			thumb_align_x = .Center
			thumb_align_y = .Top
			thumb_rel_pos = base.Vec2{-thumb_size.x / 2, thumb_offset}
		}

		// Apply defaults for Fill parameters
		thumb_bg_fill :=
			thumb_color.kind == .Not_Set ? base.fill_color(255, 200, 200) : thumb_color
		thumb_border_fill :=
			thumb_border_fill_param.kind == .Not_Set ? base.fill_color(240, 240, 240) : thumb_border_fill_param
		thumb_radius_val := math.min(thumb_size.x, thumb_size.y) / 2
		thumb_id := fmt.tprintf("%v_thumb", id)

		container(
			ctx,
			thumb_id,
			Style {
				sizing_x = sizing_fixed(thumb_size.x),
				sizing_y = sizing_fixed(thumb_size.y),
				alignment_x = thumb_align_x,
				alignment_y = thumb_align_y,
				relative_position = thumb_rel_pos,
				border_radius = border_radius_all(thumb_radius_val),
				border = thumb_border_width,
				background_fill = thumb_bg_fill,
				border_fill = thumb_border_fill,
				capability_flags = Capability_Flags{.Background},
			},
		)
		close_element(ctx)

	}
	append(&ctx.interactive_elements, element)
	return element.last_comm
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

	thumb_col := base.fill_color(80, 80, 80)
	comm := slider(
		ctx,
		id,
		val,
		0,
		target.scroll_region.max_offset[axis],
		axis,
		{20, calculated_thumb_size},
		thumb_col,
		{},
		base.fill_color(0, 0, 0, 0),
		sb_style,
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
	// TODO(Thomas): Figure out how to do the sizing properly.
	default_style := Style {
		sizing_x = sizing_grow(),
		sizing_y = sizing_fixed(48),
		layout_mode = .Relative,
		alignment_x = .Left,
		alignment_y = .Center,
		text_alignment_y = .Center,
		background_fill = base.fill_color(255, 128, 128),
		capability_flags = Capability_Flags{.Background, .Clickable, .Focusable, .Hot_Animation},
		clip = Clip_Config{clip_axes = {true, true}},
	}

	element, open_ok := open_element(ctx, id, style, default_style)
	if open_ok {

		key := ui_key_hash(element.id_string)
		state, state_exists := &ctx.text_input_states[key]

		if !state_exists {
			new_state := UI_Element_Text_Input_State{}
			// TODO(Thomas): Review which allocator to use here for the textedit.init()
			textedit.init(&new_state.state, ctx.persistent_allocator, ctx.persistent_allocator)
			new_state.builder = strings.builder_from_bytes(buf)

			if buf_len^ > 0 {
				// Sanity check to prevent reading past the buffer's capacity
				initial_len := min(buf_len^, len(buf))
				strings.write_bytes(&new_state.builder, buf[:initial_len])
			}

			new_state.state.builder = &new_state.builder

			ctx.text_input_states[key] = new_state
			state = &ctx.text_input_states[key]

			textedit.setup_once(&state.state, &state.builder)
		}

		text_content := strings.to_string(state.builder)

		buf_len^ = strings.builder_len(state.builder)

		element_equip_text(ctx, element, text_content)

		if element == ctx.active_element {
			state.caret_blink_timer += ctx.dt
			CARET_BLINK_PERIOD :: 1.0
			if math.mod(state.caret_blink_timer, CARET_BLINK_PERIOD) < CARET_BLINK_PERIOD / 2 {
				cursor_pos := state.state.selection[0]
				text_before_cursor := text_content[:cursor_pos]

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

		element.last_comm.text = text_content

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
	// TODO(Thomas): Don't hardcode min- and max_value like this.
	default_style := Style {
		sizing_x         = sizing_grow(min = 36, max = 36),
		sizing_y         = sizing_grow(min = 36, max = 36),
		capability_flags = Capability_Flags{.Background, .Clickable, .Hot_Animation},
	}

	element, open_ok := open_element(ctx, id, style, default_style)
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

push_sizing_x :: proc(ctx: ^Context, sizing: Sizing) -> bool {
	return push(&ctx.sizing_x_stack, sizing)
}

pop_sizing_x :: proc(ctx: ^Context) -> (Sizing, bool) {
	return pop(&ctx.sizing_x_stack)
}

push_sizing_y :: proc(ctx: ^Context, sizing: Sizing) -> bool {
	return push(&ctx.sizing_y_stack, sizing)
}

pop_sizing_y :: proc(ctx: ^Context) -> (Sizing, bool) {
	return pop(&ctx.sizing_y_stack)
}

push_clip_config :: proc(ctx: ^Context, clip: Clip_Config) -> bool {
	return push(&ctx.clip_stack, clip)
}

pop_clip_config :: proc(ctx: ^Context) -> (Clip_Config, bool) {
	return pop(&ctx.clip_stack)
}

push_capability_flags :: proc(ctx: ^Context, flags: Capability_Flags) -> bool {
	return push(&ctx.capability_flags_stack, flags)
}

pop_capability_flags :: proc(ctx: ^Context) -> (Capability_Flags, bool) {
	return pop(&ctx.capability_flags_stack)
}

push_background_fill :: proc(ctx: ^Context, fill: base.Fill) -> bool {
	return push(&ctx.background_fill_stack, fill)
}

pop_background_fill :: proc(ctx: ^Context) -> (base.Fill, bool) {
	return pop(&ctx.background_fill_stack)
}

push_text_fill :: proc(ctx: ^Context, fill: base.Fill) -> bool {
	return push(&ctx.text_fill_stack, fill)
}

pop_text_fill :: proc(ctx: ^Context) -> (base.Fill, bool) {
	return pop(&ctx.text_fill_stack)
}

push_padding :: proc(ctx: ^Context, padding: Padding) -> bool {
	return push(&ctx.padding_stack, padding)
}

pop_padding :: proc(ctx: ^Context) -> (Padding, bool) {
	return pop(&ctx.padding_stack)
}

push_margin :: proc(ctx: ^Context, margin: Margin) -> bool {
	return push(&ctx.margin_stack, margin)
}

pop_margin :: proc(ctx: ^Context) -> (Margin, bool) {
	return pop(&ctx.margin_stack)
}

push_child_gap :: proc(ctx: ^Context, child_gap: f32) -> bool {
	return push(&ctx.child_gap_stack, child_gap)
}

pop_child_gap :: proc(ctx: ^Context) -> (f32, bool) {
	return pop(&ctx.child_gap_stack)
}

push_layout_mode :: proc(ctx: ^Context, layout_mode: Layout_Mode) -> bool {
	return push(&ctx.layout_mode_stack, layout_mode)
}

pop_layout_mode :: proc(ctx: ^Context) -> (Layout_Mode, bool) {
	return pop(&ctx.layout_mode_stack)
}

push_layout_direction :: proc(ctx: ^Context, layout_direction: Layout_Direction) -> bool {
	return push(&ctx.layout_direction_stack, layout_direction)
}

pop_layout_direction :: proc(ctx: ^Context) -> (Layout_Direction, bool) {
	return pop(&ctx.layout_direction_stack)
}

push_relative_position :: proc(ctx: ^Context, relative_position: base.Vec2) -> bool {
	return push(&ctx.relative_position_stack, relative_position)
}

pop_relative_position :: proc(ctx: ^Context) -> (base.Vec2, bool) {
	return pop(&ctx.relative_position_stack)
}

push_alignment_x :: proc(ctx: ^Context, aligment_x: Alignment_X) -> bool {
	return push(&ctx.alignment_x_stack, aligment_x)
}

pop_alignment_x :: proc(ctx: ^Context) -> (Alignment_X, bool) {
	return pop(&ctx.alignment_x_stack)
}

push_alignment_y :: proc(ctx: ^Context, aligment_y: Alignment_Y) -> bool {
	return push(&ctx.alignment_y_stack, aligment_y)
}

pop_alignment_y :: proc(ctx: ^Context) -> (Alignment_Y, bool) {
	return pop(&ctx.alignment_y_stack)
}

push_text_padding :: proc(ctx: ^Context, padding: Padding) -> bool {
	return push(&ctx.text_padding_stack, padding)
}

pop_text_padding :: proc(ctx: ^Context) -> (Padding, bool) {
	return pop(&ctx.text_padding_stack)
}

push_text_alignment_x :: proc(ctx: ^Context, aligment_x: Alignment_X) -> bool {
	return push(&ctx.text_alignment_x_stack, aligment_x)
}

pop_text_alignment_x :: proc(ctx: ^Context) -> (Alignment_X, bool) {
	return pop(&ctx.text_alignment_x_stack)
}

push_text_alignment_y :: proc(ctx: ^Context, aligment_y: Alignment_Y) -> bool {
	return push(&ctx.text_alignment_y_stack, aligment_y)
}

pop_text_alignment_y :: proc(ctx: ^Context) -> (Alignment_Y, bool) {
	return pop(&ctx.text_alignment_y_stack)
}

push_border_radius :: proc(ctx: ^Context, border_radius: base.Vec4) -> bool {
	return push(&ctx.border_radius_stack, border_radius)
}

pop_border_radius :: proc(ctx: ^Context) -> (base.Vec4, bool) {
	return pop(&ctx.border_radius_stack)
}

push_border :: proc(ctx: ^Context, border: Border) -> bool {
	return push(&ctx.border_stack, border)
}

pop_border :: proc(ctx: ^Context) -> (Border, bool) {
	return pop(&ctx.border_stack)
}

push_border_fill :: proc(ctx: ^Context, fill: base.Fill) -> bool {
	return push(&ctx.border_fill_stack, fill)
}

pop_border_fill :: proc(ctx: ^Context) -> (base.Fill, bool) {
	return pop(&ctx.border_fill_stack)
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
