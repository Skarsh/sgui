package ui

import "core:container/queue"
import "core:fmt"
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

Command :: union {
	Command_Rect,
	Command_Text,
	Command_Image,
	Command_Push_Scissor,
	Command_Pop_Scissor,
}

Command_Rect :: struct {
	rect:             base.Rect,
	fill:             base.Fill,
	border_fill:      base.Fill,
	radius:           f32,
	border_thickness: f32,
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


Context :: struct {
	persistent_allocator:    mem.Allocator,
	frame_allocator:         mem.Allocator,
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
	child_gap_stack:         Stack(f32, STYLE_STACK_SIZE),
	layout_mode_stack:       Stack(Layout_Mode, STYLE_STACK_SIZE),
	layout_direction_stack:  Stack(Layout_Direction, STYLE_STACK_SIZE),
	relative_position_stack: Stack(base.Vec2, STYLE_STACK_SIZE),
	alignment_x_stack:       Stack(Alignment_X, STYLE_STACK_SIZE),
	alignment_y_stack:       Stack(Alignment_Y, STYLE_STACK_SIZE),
	text_padding_stack:      Stack(Padding, STYLE_STACK_SIZE),
	text_alignment_x_stack:  Stack(Alignment_X, STYLE_STACK_SIZE),
	text_alignment_y_stack:  Stack(Alignment_Y, STYLE_STACK_SIZE),
	corner_radius_stack:     Stack(f32, STYLE_STACK_SIZE),
	border_thickness_stack:  Stack(f32, STYLE_STACK_SIZE),
	border_fill_stack:       Stack(base.Fill, STYLE_STACK_SIZE),
	command_queue:           [dynamic]Command,
	current_parent:          ^UI_Element,
	root_element:            ^UI_Element,
	input:                   Input,
	element_cache:           map[UI_Key]^UI_Element,
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
	// TODO(Thomas): This is just temporary for experimenting with a single text input
	// this needs to be revised when we got a basic text input working.
	text_builder:            strings.Builder,
	text_state:              textedit.State,
}

Capability :: enum {
	Background,
	Text,
	Image,
	Active_Animation,
	Hot_Animation,
	Clickable,
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
	screen_size: [2]i32,
	font_id: u16,
	font_size: f32,
) {
	ctx^ = {} // zero memory
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.window_size = screen_size
	ctx.font_id = font_id
	ctx.font_size = font_size

	ctx.command_queue = make([dynamic]Command, frame_allocator)
	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)
	ctx.interactive_elements = make([dynamic]^UI_Element, persistent_allocator)
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

	background_fill := base.Fill(base.Color{128, 128, 128, 255})
	sizing_x := Sizing {
		kind  = .Fixed,
		value = f32(ctx.window_size.x),
	}
	sizing_y := Sizing {
		kind  = .Fixed,
		value = f32(ctx.window_size.y),
	}

	// Open the root element
	_, root_open_ok := open_element(
		ctx,
		"root",
		{background_fill = &background_fill, layout = {sizing = {&sizing_x, &sizing_y}}},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)

	//NOTE(Thomas): Root element size needs to be updated every frame, meaning not cached like other elements.
	if root_element != nil {
		root_element.size.x = f32(ctx.window_size.x)
		root_element.size.y = f32(ctx.window_size.y)
	}

	ctx.root_element = root_element
	return root_open_ok
}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Percentage of parent
	// 2. Fit sizing widths
	// 3. Resolve dependent sizs widths
	// 4. Wrap text
	// 5. Fit sizing heights
	// 6. Resolve dependent sizs heights
	// 7. Positions
	// 8. Draw commands
	// 9. Process interactions

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Fit sizing widths
	fit_size_axis(ctx.root_element, .X)

	// Resolve dependent widths
	resolve_dependent_sizes_for_axis(ctx.root_element, .X)

	// Wrap text
	wrap_text(ctx, ctx.root_element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Reolve dependent heights
	resolve_dependent_sizes_for_axis(ctx.root_element, .Y)

	calculate_positions_and_alignment(ctx.root_element)

	process_interactions(ctx)

	draw_all_elements(ctx)

	clear_input(ctx)

	ctx.frame_idx += 1
}

process_interactions :: proc(ctx: ^Context) {
	top_element: ^UI_Element
	highest_z_index: i32 = -1

	// BFS traversal, we're traversing the layout hierarchy instead
	// of iterating over the element_cache because in this way we
	// know we'll always just have fresh and existing UI_Elements.
	q := queue.Queue(^UI_Element){}
	queue.init(&q, allocator = ctx.frame_allocator)
	visited := make([dynamic]^UI_Element, ctx.frame_allocator)

	queue.push_back(&q, ctx.root_element)
	for queue.len(q) > 0 {
		v := queue.pop_front(&q)

		rect := base.Rect{i32(v.position.x), i32(v.position.y), i32(v.size.x), i32(v.size.y)}

		if base.point_in_rect(ctx.input.mouse_pos, rect) {
			if .Clickable in v.config.capability_flags {
				if v.z_index > highest_z_index {
					highest_z_index = v.z_index
					top_element = v
				}
			}
		}

		for child in v.children {
			found := false
			for n in visited {
				if child.id_string == n.id_string {
					found = true
				}
			}
			if !found {
				append(&visited, child)
				queue.push_back(&q, child)
			}
		}
	}

	// TODO(Thomas): This isn't going to work for long.
	// An element should be active until clicked on another element
	// End an interaction if the mouse is released
	if is_mouse_released(ctx^, .Left) {
		ctx.active_element = nil
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
				ctx.active_element = element
				comm.clicked = true
				comm.held = true
				element.active = 1.0
			}
		}

		// Reset active animation if not active anymore
		if !is_active_element && is_mouse_released(ctx^, .Left) {
			element.active = 0
		}

		// Clamp animations and set final comm state
		element.hot = math.clamp(element.hot, 0, 1)

		if base.approx_equal(element.active, 1.0, 0.001) {
			comm.active = true
		}

		if base.approx_equal(element.hot, 1.0, 0.001) {
			comm.hot = true
		}

		element.last_comm = comm
	}
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	if element == nil {
		return
	}

	clipping_this_element := element.config.clip.clip_axes.x || element.config.clip.clip_axes.y
	if clipping_this_element {
		scissor_rect := base.Rect {
			x = i32(element.position.x),
			y = i32(element.position.y),
			w = i32(element.size.x),
			h = i32(element.size.y),
		}

		if !element.config.clip.clip_axes.x {
			scissor_rect.x = 0
			scissor_rect.w = ctx.window_size.x
		}

		if !element.config.clip.clip_axes.y {
			scissor_rect.y = 0
			scissor_rect.h = ctx.window_size.y
		}

		append(&ctx.command_queue, Command_Push_Scissor{rect = scissor_rect})
	}

	cap_flags := element.config.capability_flags
	final_bg_fill := element.fill

	last_comm := element.last_comm

	// TODO(Thomas): Click could have an embossed / debossed animation effect instead.
	// There's lots left to figure out for hot and active too, it could be highlighted with
	// a border instead or many other things. This is a temporary a solution.
	switch fill in final_bg_fill {
	case base.Color:
		if .Hot_Animation in cap_flags {
			hot_color := default_color_style[.Hot]
			final_bg_fill = base.lerp_color(final_bg_fill.(base.Color), hot_color, element.hot)
		}

		if .Active_Animation in cap_flags {
			active_color := default_color_style[.Active]
			final_bg_fill = base.lerp_color(
				final_bg_fill.(base.Color),
				active_color,
				element.active,
			)
		}

		if .Clickable in cap_flags {
			if last_comm.held {
				click_color := default_color_style[.Click]
				final_bg_fill = click_color
			}
		}

	case base.Gradient:
		gradient := final_bg_fill.(base.Gradient)

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

		final_bg_fill = gradient

		if .Clickable in cap_flags {
			if last_comm.held {
				click_color := default_color_style[.Click]
				final_bg_fill = click_color
			}
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
			element.config.layout.corner_radius,
			element.config.layout.border_thickness,
			element.config.border_fill,
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

			draw_text(ctx, start_x, current_y, line.text, element.config.text_fill)
			current_y += line.height
		}
	}


	for child in element.children {
		draw_element(ctx, child)
	}

	if clipping_this_element {
		append(&ctx.command_queue, Command_Pop_Scissor{})
	}

}

draw_all_elements :: proc(ctx: ^Context) {
	draw_element(ctx, ctx.root_element)
}

draw_rect :: proc(
	ctx: ^Context,
	rect: base.Rect,
	fill: base.Fill,
	radius: f32,
	border_thickness: f32,
	border_fill: base.Fill,
) {
	append(&ctx.command_queue, Command_Rect{rect, fill, border_fill, radius, border_thickness})
}

draw_text :: proc(ctx: ^Context, x, y: f32, str: string, color: base.Fill) {
	append(&ctx.command_queue, Command_Text{x, y, str, color})
}

draw_image :: proc(ctx: ^Context, x, y, w, h: f32, data: rawptr) {
	append(&ctx.command_queue, Command_Image{x, y, w, h, data})
}


// Determines the final value for a property by checking sources in a specific order.
// Precedence:
// 1. The user-provided value (if it exists).
// 2. The value from the top of the style stack (if it exists).
// 3. The provided default value.
@(private)
resolve_value :: proc(user_value: ^$T, stack: ^Stack(T, $N), default_value: T) -> T {
	if user_value != nil {
		return user_value^
	}

	if val, ok := peek(stack); ok {
		return val
	}

	return default_value
}

@(private)
resolve_default :: proc(user_value: ^$T) -> T {
	if user_value != nil {
		return user_value^
	}

	return T{}
}


text :: proc(ctx: ^Context, id, text: string, opts: Config_Options = {}) {
	default_text_padding := Padding{}
	default_text_alignment_x := Alignment_X.Left
	default_text_alignment_y := Alignment_Y.Top
	default_text_fill := base.Fill(base.Color{255, 255, 255, 255})

	default_opts := Config_Options {
		layout = {
			text_padding = &default_text_padding,
			text_alignment_x = &default_text_alignment_x,
			text_alignment_y = &default_text_alignment_y,
		},
		text_fill = &default_text_fill,
	}

	element, open_ok := open_element(ctx, id, opts, default_opts)
	assert(open_ok)
	if open_ok {
		element_equip_text(ctx, element, text)
		close_element(ctx)
	}
}

button :: proc(ctx: ^Context, id, text: string, opts: Config_Options = {}) -> Comm {
	sizing_grow := Sizing {
		kind = .Grow,
	}

	text_padding := Padding {
		left   = 10,
		top    = 10,
		right  = 10,
		bottom = 10,
	}

	text_alignment_x := Alignment_X.Center
	background_fill := base.Fill(base.Color{24, 24, 24, 255})
	text_fill := base.Fill(base.Color{255, 128, 255, 128})
	capability_flags := Capability_Flags{.Background, .Clickable, .Hot_Animation}
	clip := Clip_Config{{true, true}}

	default_opts := Config_Options {
		layout = {
			sizing = {&sizing_grow, &sizing_grow},
			text_padding = &text_padding,
			text_alignment_x = &text_alignment_x,
		},
		background_fill = &background_fill,
		text_fill = &text_fill,
		capability_flags = &capability_flags,
		clip = &clip,
	}

	element, open_ok := open_element(ctx, id, opts, default_opts)

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
	opts: Config_Options = {},
) -> Comm {
	sizing_x := Sizing {
		kind = .Grow,
	}
	sizing_y := Sizing {
		kind  = .Fixed,
		value = 20,
	}
	background_fill := base.Fill(base.Color{24, 24, 24, 255})
	capability_flags := Capability_Flags{.Background, .Clickable, .Hot_Animation}
	layout_mode: Layout_Mode = .Relative
	corner_radius: f32 = 2

	default_opts := Config_Options {
		layout = {
			sizing = {&sizing_x, &sizing_y},
			layout_mode = &layout_mode,
			corner_radius = &corner_radius,
		},
		background_fill = &background_fill,
		capability_flags = &capability_flags,
	}

	element, open_ok := open_element(ctx, id, opts, default_opts)
	if open_ok {

		// Thumb propertis
		thumb_width: f32 = 20
		thumb_height: f32 = 20

		padding := element.config.layout.padding
		content_width := element.size.x - padding.left - padding.right

		range := max - min

		// Handle mouse dragging to update the slider's value
		if element.last_comm.held && content_width > 0 {
			mouse_relative_x := f32(ctx.input.mouse_pos.x) - (element.position.x + padding.left)
			new_ratio := math.clamp(mouse_relative_x / content_width, 0, 1)
			value^ = min + (new_ratio * range)
		}

		// Calculate the ratio based on the current value
		ratio: f32 = 0
		if range != 0 {
			ratio = (value^ - min) / range
		}

		// Calculate positions, keeping thumb inside bounds
		// The total distance the thumb's left edge can travel
		thumb_travel_width := content_width - thumb_width
		thumb_relative_pos_x := ratio * thumb_travel_width

		// Thumb
		thumb_sizing := [2]Sizing {
			{kind = .Fixed, value = thumb_width},
			{kind = .Fixed, value = thumb_height},
		}
		thumb_align_x := Alignment_X.Left
		thumb_align_y := Alignment_Y.Center
		thumb_rel_pos := base.Vec2{thumb_relative_pos_x, 0}
		thumb_bg_fill := base.Fill(base.Color{255, 200, 200, 255})
		thumb_caps := Capability_Flags{.Background}
		thumb_radius: f32 = thumb_width / 2
		thumb_id := fmt.tprintf("%v_thumb", id)

		container(
			ctx,
			thumb_id,
			Config_Options {
				layout = {
					sizing = {&thumb_sizing.x, &thumb_sizing.y},
					alignment_x = &thumb_align_x,
					alignment_y = &thumb_align_y,
					relative_position = &thumb_rel_pos,
					corner_radius = &thumb_radius,
				},
				background_fill = &thumb_bg_fill,
				capability_flags = &thumb_caps,
			},
		)

		close_element(ctx)
	}

	append(&ctx.interactive_elements, element)
	return element.last_comm
}

// TODO(Thomas): The backing buffer is provided by the user, so we don't need to cache that,
// but should we cache the builder and text_edit, so we don't have to re-create that every frame?
text_input :: proc(ctx: ^Context, id: string, buf: []u8, opts: Config_Options = {}) -> Comm {
	sizing_x := Sizing {
		kind = .Grow,
	}
	sizing_y := Sizing {
		kind = .Fit,
	}

	background_fill := base.Fill(base.Color{24, 24, 24, 255})
	capability_flags := Capability_Flags{.Background, .Clickable, .Hot_Animation}

	default_opts := Config_Options {
		layout = {sizing = {&sizing_x, &sizing_y}},
		background_fill = &background_fill,
		capability_flags = &capability_flags,
	}

	element, open_ok := open_element(ctx, id, opts, default_opts)
	if open_ok {

		ctx.text_builder = strings.builder_from_bytes(buf)
		ctx.text_state.builder = &ctx.text_builder

		text_content := strings.to_string(ctx.text_builder)

		text_id := fmt.tprintf("%v_text", id)
		text_alignment_x := Alignment_X.Center
		text(
			ctx,
			text_id,
			text_content,
			Config_Options{layout = {text_alignment_x = &text_alignment_x}},
		)


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

push_corner_radius :: proc(ctx: ^Context, radius: f32) -> bool {
	return push(&ctx.corner_radius_stack, radius)
}

pop_corner_radius :: proc(ctx: ^Context) -> (f32, bool) {
	return pop(&ctx.corner_radius_stack)
}

push_border_thickness :: proc(ctx: ^Context, thickness: f32) -> bool {
	return push(&ctx.border_thickness_stack, thickness)
}

pop_border_thickness :: proc(ctx: ^Context) -> (f32, bool) {
	return pop(&ctx.border_thickness_stack)
}

push_border_fill :: proc(ctx: ^Context, fill: base.Fill) -> bool {
	return push(&ctx.border_fill_stack, fill)
}

pop_border_fill :: proc(ctx: ^Context) -> (base.Fill, bool) {
	return pop(&ctx.border_fill_stack)
}
