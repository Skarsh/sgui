package ui

import "core:container/queue"
import "core:math"
import "core:mem"

import base "../base"

COMMAND_STACK_SIZE :: #config(SUI_COMMAND_STACK_SIZE, 100)
ELEMENT_STACK_SIZE :: #config(SUI_ELEMENT_STACK_SIZE, 64)
PARENT_STACK_SIZE :: #config(SUI_PARENT_STACK_SIZE, 64)
STYLE_STACK_SIZE :: #config(SUI_STYLE_STACK_SIZE, 64)
CHILD_LAYOUT_AXIS_STACK_SIZE :: #config(SUI_CHILD_LAYOUT_AXIS_STACK_SIZE, 64)
MAX_TEXT_STORE :: #config(SUI_MAX_TEXT_STORE, 1024)

Color_Type :: enum u32 {
	Text,
	Selection_BG,
	Window_BG,
	Hot,
	Active,
	Base,
}

Command :: union {
	Command_Rect,
	Command_Text,
	Command_Image,
	Command_Push_Scissor,
	Command_Pop_Scissor,
}

Command_Rect :: struct {
	rect:  base.Rect,
	color: base.Color,
}

Command_Text :: struct {
	x, y:  f32,
	str:   string,
	color: base.Color,
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
	persistent_allocator:   mem.Allocator,
	frame_allocator:        mem.Allocator,
	command_stack:          Stack(Command, COMMAND_STACK_SIZE),
	element_stack:          Stack(^UI_Element, ELEMENT_STACK_SIZE),
	// TODO(Thomas): Style stacks, move them into its own struct?
	// Maybe even do some metaprogramming to generate them if it becomes
	// too many of them?
	sizing_x_stack:         Stack(Sizing, STYLE_STACK_SIZE),
	sizing_y_stack:         Stack(Sizing, STYLE_STACK_SIZE),
	clip_stack:             Stack(Clip_Config, STYLE_STACK_SIZE),
	capability_flags_stack: Stack(Capability_Flags, STYLE_STACK_SIZE),
	background_color_stack: Stack(base.Color, STYLE_STACK_SIZE),
	text_color_stack:       Stack(base.Color, STYLE_STACK_SIZE),
	padding_stack:          Stack(Padding, STYLE_STACK_SIZE),
	child_gap_stack:        Stack(f32, STYLE_STACK_SIZE),
	layout_direction_stack: Stack(Layout_Direction, STYLE_STACK_SIZE),
	alignment_x_stack:      Stack(Alignment_X, STYLE_STACK_SIZE),
	alignment_y_stack:      Stack(Alignment_Y, STYLE_STACK_SIZE),
	text_padding_stack:     Stack(Padding, STYLE_STACK_SIZE),
	text_alignment_x_stack: Stack(Alignment_X, STYLE_STACK_SIZE),
	text_alignment_y_stack: Stack(Alignment_Y, STYLE_STACK_SIZE),
	current_parent:         ^UI_Element,
	root_element:           ^UI_Element,
	input:                  Input,
	element_cache:          map[UI_Key]^UI_Element,
	interactive_elements:   [dynamic]^UI_Element,
	measure_text_proc:      Measure_Text_Proc,
	measure_glyph_proc:     Measure_Glyph_Proc,
	font_user_data:         rawptr,
	frame_idx:              u64,
	dt:                     f32,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:              f32,
	font_id:                u16,
	window_size:            [2]i32,
}

Capability :: enum {
	Background,
	Text,
	Image,
	Active_Animation,
	Hot_Animation,
}

Capability_Flags :: bit_set[Capability]

Comm :: struct {
	element:  ^UI_Element,
	active:   bool,
	hot:      bool,
	clicked:  bool,
	held:     bool,
	hovering: bool,
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

begin :: proc(ctx: ^Context) {
	clear(&ctx.command_stack)
	clear_dynamic_array(&ctx.interactive_elements)

	// Open the root element
	_, root_open_ok := open_element(
		ctx,
		"root",
		{
			background_color = base.Color{128, 128, 128, 255},
			layout = {
				sizing = {
					Sizing{kind = .Fixed, value = f32(ctx.window_size.x)},
					Sizing{kind = .Fixed, value = f32(ctx.window_size.y)},
				},
			},
		},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)
	ctx.root_element = root_element
}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Percentage of parent
	// 2. Fit sizing widths
	// 3. Grow & shrink sizing widths
	// 4. Wrap text
	// 5. Fit sizing heights
	// 6. Grow & shrink sizing heights
	// 7. Positions
	// 8. Draw commands
	// 9. Process interactions

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Percentage of parent sizing
	resolve_percentage_sizing(ctx.root_element, .X)

	// Fit sizing widths
	fit_size_axis(ctx.root_element, .X)
	// Resize widths
	resize_child_elements_for_axis(ctx.root_element, .X)

	// Wrap text
	wrap_text(ctx, ctx.root_element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	// Percentage of parent sizing
	resolve_percentage_sizing(ctx.root_element, .Y)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Resize heights
	resize_child_elements_for_axis(ctx.root_element, .Y)

	calculate_positions_and_alignment(ctx.root_element)

	process_interactions(ctx)

	draw_all_elements(ctx)

	clear_input(ctx)

	ctx.frame_idx += 1

	free_all(ctx.frame_allocator)
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

		if point_in_rect(ctx.input.mouse_pos, rect) {
			if v.z_index > highest_z_index {
				highest_z_index = v.z_index
				top_element = v
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

	for element in ctx.interactive_elements {
		comm := Comm {
			element = element,
		}

		button_animation_rate_of_change := (1.0 / 0.2) * ctx.dt

		is_top_element := (top_element != nil && top_element.id_string == element.id_string)

		if is_top_element {
			comm.hovering = true
			element.hot += button_animation_rate_of_change

			if is_mouse_pressed(ctx^, .Left) {
				comm.clicked = true
				element.active = 1.0
			}

			if is_mouse_down(ctx^, .Left) {
				comm.held = true
			}
		} else {
			// This element is not the top one, so it's not hot or active from this frame's input.
			element.hot -= button_animation_rate_of_change
			if is_mouse_pressed(ctx^, .Left) {
				element.active = 0.0
			}
		}

		element.hot = math.clamp(element.hot, 0, 1)

		if approx_equal(element.active, 1.0, 0.001) {
			comm.active = true
		}

		if approx_equal(element.hot, 1.0, 0.001) {
			comm.hot = true
		}

		element.last_comm = comm
	}
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	if element == nil {
		return
	}

	cap_flags := element.config.capability_flags

	final_bg_color := element.color

	if .Hot_Animation in cap_flags {
		hot_color := default_color_style[.Hot]
		final_bg_color = lerp_color(final_bg_color, hot_color, element.hot)
	}

	if .Active_Animation in cap_flags {
		active_color := default_color_style[.Active]
		final_bg_color = lerp_color(final_bg_color, active_color, element.active)
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
			final_bg_color,
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

			draw_text(ctx, start_x, current_y, line.text, element.config.text_color)
			current_y += line.height
		}
	}


	// NOTE(Thomas): We don't clip the current element, it's only for its children elements
	clipping_this_element := element.config.clip.clip_axes.x || element.config.clip.clip_axes.y
	padding := element.config.layout.padding
	if clipping_this_element {
		scissor_rect := base.Rect {
			x = i32(element.position.x + padding.left),
			y = i32(element.position.y + padding.top),
			w = i32(element.size.x - padding.left - padding.right),
			h = i32(element.size.y - padding.top - padding.bottom),
		}

		if !element.config.clip.clip_axes.x {
			scissor_rect.x = 0
			scissor_rect.w = ctx.window_size.x
		}

		if !element.config.clip.clip_axes.y {
			scissor_rect.y = 0
			scissor_rect.h = ctx.window_size.y
		}

		push(&ctx.command_stack, Command_Push_Scissor{rect = scissor_rect})
	}

	for child in element.children {
		draw_element(ctx, child)
	}

	if clipping_this_element {
		push(&ctx.command_stack, Command_Pop_Scissor{})
	}

}

draw_all_elements :: proc(ctx: ^Context) {
	draw_element(ctx, ctx.root_element)
}

draw_rect :: proc(ctx: ^Context, rect: base.Rect, color: base.Color) {
	push(&ctx.command_stack, Command_Rect{rect, color})
}

draw_text :: proc(ctx: ^Context, x, y: f32, str: string, color: base.Color) {
	push(&ctx.command_stack, Command_Text{x, y, str, color})
}

draw_image :: proc(ctx: ^Context, x, y, w, h: f32, data: rawptr) {
	push(&ctx.command_stack, Command_Image{x, y, w, h, data})
}


// Determines the final value for a property by checking sources in a specific order.
// Precedence:
// 1. The user-provided value (if it exists).
// 2. The value from the top of the style stack (if it exists).
// 3. The provided default value.
@(private)
resolve_value :: proc(user_value: Maybe($T), stack: ^Stack(T, $N), default_value: T) -> T {
	if val, ok := user_value.?; ok {
		return val
	}

	if val, ok := peek(stack); ok {
		return val
	}

	return default_value
}

@(private)
resolve_default :: proc(user_value: Maybe($T)) -> T {
	if val, ok := user_value.?; ok {
		return val
	}

	return T{}
}

button :: proc(ctx: ^Context, id, text: string, opts: Config_Options = {}) -> Comm {
	default_opts := Config_Options {
		layout = {
			sizing = {Sizing{kind = .Grow}, Sizing{kind = .Grow}},
			text_padding = Padding{left = 10, top = 10, right = 10, bottom = 10},
			text_alignment_x = .Center,
		},
		background_color = base.Color{24, 24, 24, 255},
		text_color = base.Color{255, 128, 255, 128},
		capability_flags = Capability_Flags{.Background, .Active_Animation, .Hot_Animation},
	}

	element, open_ok := open_element(ctx, id, opts, default_opts)

	if open_ok {
		element_equip_text(ctx, element, text)
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

push_background_color :: proc(ctx: ^Context, color: base.Color) -> bool {
	return push(&ctx.background_color_stack, color)
}

pop_background_color :: proc(ctx: ^Context) -> (base.Color, bool) {
	return pop(&ctx.background_color_stack)
}

push_text_color :: proc(ctx: ^Context, color: base.Color) -> bool {
	return push(&ctx.text_color_stack, color)
}

pop_text_color :: proc(ctx: ^Context) -> (base.Color, bool) {
	return pop(&ctx.text_color_stack)
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

push_layout_direction :: proc(ctx: ^Context, layout_direction: Layout_Direction) -> bool {
	return push(&ctx.layout_direction_stack, layout_direction)
}

pop_layout_direction :: proc(ctx: ^Context) -> (Layout_Direction, bool) {
	return pop(&ctx.layout_direction_stack)
}

push_alignment_x :: proc(ctx: ^Context, aligment_x: Alignment_X) -> bool {
	return push(&ctx.alignment_x_stack, aligment_x)
}

pop_aligment_x :: proc(ctx: ^Context) -> (Alignment_X, bool) {
	return pop(&ctx.alignment_x_stack)
}

push_alignment_y :: proc(ctx: ^Context, aligment_y: Alignment_Y) -> bool {
	return push(&ctx.alignment_y_stack, aligment_y)
}

pop_aligment_y :: proc(ctx: ^Context) -> (Alignment_Y, bool) {
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

pop_text_aligment_x :: proc(ctx: ^Context) -> (Alignment_X, bool) {
	return pop(&ctx.text_alignment_x_stack)
}

push_text_alignment_y :: proc(ctx: ^Context, aligment_y: Alignment_Y) -> bool {
	return push(&ctx.text_alignment_y_stack, aligment_y)
}

pop_text_aligment_y :: proc(ctx: ^Context) -> (Alignment_Y, bool) {
	return pop(&ctx.text_alignment_y_stack)
}
