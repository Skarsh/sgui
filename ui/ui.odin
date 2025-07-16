package ui

import "core:mem"

COMMAND_STACK_SIZE :: #config(SUI_COMMAND_STACK_SIZE, 100)
ELEMENT_STACK_SIZE :: #config(SUI_ELEMENT_STACK_SIZE, 64)
PARENT_STACK_SIZE :: #config(SUI_PARENT_STACK_SIZE, 64)
STYLE_STACK_SIZE :: #config(SUI_STYLE_STACK_SIZE, 64)
CHILD_LAYOUT_AXIS_STACK_SIZE :: #config(SUI_CHILD_LAYOUT_AXIS_STACK_SIZE, 64)
MAX_TEXT_STORE :: #config(SUI_MAX_TEXT_STORE, 1024)

Vec2 :: [2]f32
Vector2i32 :: [2]i32

Color_Type :: enum u32 {
	Text,
	Selection_BG,
	Window_BG,
	Hot,
	Active,
	Base,
}

Color :: struct {
	r, g, b, a: u8,
}

// x, y is the upper left corner of the rect
Rect :: struct {
	x, y, w, h: i32,
}

Command :: union {
	Command_Rect,
	Command_Text,
	Command_Image,
	Command_Push_Scissor,
	Command_Pop_Scissor,
}

Command_Rect :: struct {
	rect:  Rect,
	color: Color,
}

Command_Text :: struct {
	x, y: f32,
	str:  string,
}

Command_Image :: struct {
	x, y, w, h: f32,
	data:       rawptr,
}

Command_Push_Scissor :: struct {
	rect: Rect,
}

Command_Pop_Scissor :: struct {}

Color_Style :: [Color_Type]Color

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
	persistent_allocator: mem.Allocator,
	frame_allocator:      mem.Allocator,
	command_stack:        Stack(Command, COMMAND_STACK_SIZE),
	element_stack:        Stack(^UI_Element, ELEMENT_STACK_SIZE),
	current_parent:       ^UI_Element,
	root_element:         ^UI_Element,
	input:                Input,
	element_cache:        map[UI_Key]^UI_Element,
	measure_text_proc:    Measure_Text_Proc,
	measure_glyph_proc:   Measure_Glyph_Proc,
	font_user_data:       rawptr,
	frame_index:          u64,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:            f32,
	font_id:              u16,
	screen_size:          [2]i32,
}

Capability :: enum {
	Background,
	Text,
	Image,
}

Capability_Flags :: bit_set[Capability]

Comm :: struct {
	element:  ^UI_Element,
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
) {
	ctx^ = {} // zero memory
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.screen_size = screen_size

	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)
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

	// Open the root element
	_, root_open_ok := open_element(
		ctx,
		"root",
		{
			background_color = Color{128, 128, 128, 255},
			layout = {sizing = {{kind = .Fit}, {kind = .Fit}}},
		},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)
	ctx.root_element = root_element

}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Fit sizing widths
	// 2. Grow & shrink sizing widths
	// 3. Wrap text
	// 4. Fit sizing heights
	// 5. Grow & shrink sizing heights
	// 6. Positions
	// 7. Draw commands

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Fit sizing widths
	fit_size_axis(ctx.root_element, .X)
	// Resize widths
	resize_child_elements_for_axis(ctx.root_element, .X)

	// Wrap text
	wrap_text(ctx, ctx.root_element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Resize heights
	resize_child_elements_for_axis(ctx.root_element, .Y)

	calculate_positions_and_alignment(ctx.root_element)

	draw_all_elements(ctx)

	clear_input(ctx)

	free_all(ctx.frame_allocator)
}


// TODO(Thomas): It is very wasteful to recalculate the intersection elements
// for every element that will call `comm_from_element`. This should probably
// only be done once, and cached in the Context for the next frame.
// This is a temporary solution just to see how to code will look like.
comm_from_element :: proc(ctx: ^Context, element: ^UI_Element) -> Comm {
	intersection_elements, alloc_err := make([dynamic]^UI_Element, context.temp_allocator)
	assert(alloc_err == .None)
	defer free_all(context.temp_allocator)

	// TODO(Thomas): Two things here:
	// 1. What is the performance cost of looping
	// over key,value pairs in a map like this.
	// 2. Will it be an issue using the elements from the cache here?
	// It should always be up-to-date.
	for _, elem in ctx.element_cache {
		rect := Rect {
			i32(elem.position.x),
			i32(elem.position.y),
			i32(elem.size.x),
			i32(elem.size.y),
		}

		if point_in_rect(ctx.input.mouse_pos, rect) {
			append(&intersection_elements, elem)
		}
	}

	// Iterate through the intersection elements and find the one
	// with the highest z_index
	top_element: ^UI_Element
	highest_z_index: i32 = 0
	for elem in intersection_elements {
		if elem.z_index > highest_z_index {
			highest_z_index = elem.z_index
			top_element = elem
		}
	}


	comm := Comm {
		element = element,
	}

	if top_element != nil {
		// TODO(Thomas): We should probably use the key for this instead
		// of the id string.
		if top_element.id_string == element.id_string {
			// Since we're already intersecting, we're hovering too
			comm.hovering = true

			if is_mouse_pressed(ctx^, .Left) {
				comm.clicked = true
			}

			if is_mouse_down(ctx^, .Left) {
				comm.held = true
			}

		}
	}

	return comm
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	if element == nil {
		return
	}

	if .Text in element.config.capability_flags {
		// Define the content area
		padding := element.config.layout.padding
		content_area_x := element.position.x + padding.left
		content_area_y := element.position.y + padding.top
		content_area_w := element.size.x - padding.left - padding.right
		content_area_h := element.size.y - padding.top - padding.bottom

		// Calculate the total height of the entire text block
		total_text_height: f32 = 0
		for line in element.content.text_data.lines {
			total_text_height += line.height
		}

		// Calculate the initial vertical offset for the whole block based on Aligment_Y
		start_y: f32 = content_area_y
		switch element.config.layout.alignment_y {
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

		for line in element.content.text_data.lines {
			start_x: f32 = content_area_x
			switch element.config.layout.alignment_x {
			case .Left:
				// Default, no change
				start_x = content_area_x
			case .Center:
				start_x = content_area_x + (content_area_w - line.width) / 2
			case .Right:
				start_x = content_area_x + (content_area_w - line.width)
			}

			draw_text(ctx, start_x, current_y, line.text)
			current_y += line.height
		}
	}

	if .Image in element.config.capability_flags {
		draw_image(
			ctx,
			element.position.x,
			element.position.y,
			element.size.x,
			element.size.y,
			nil,
		)
	}

	if .Background in element.config.capability_flags {
		draw_rect(
			ctx,
			Rect {
				i32(element.position.x),
				i32(element.position.y),
				i32(element.size.x),
				i32(element.size.y),
			},
			element.color,
		)
	}


	// NOTE(Thomas): We don't clip the current element, it's only for its children elements
	clipping_this_element := element.config.clip.clip_axes.x || element.config.clip.clip_axes.y
	padding := element.config.layout.padding
	if clipping_this_element {
		scissor_rect := Rect {
			x = i32(element.position.x + padding.left),
			y = i32(element.position.y + padding.top),
			w = i32(element.size.x - padding.left - padding.right),
			h = i32(element.size.y - padding.top - padding.bottom),
		}

		if !element.config.clip.clip_axes.x {
			scissor_rect.x = 0
			scissor_rect.w = ctx.screen_size.x
		}

		if !element.config.clip.clip_axes.y {
			scissor_rect.y = 0
			scissor_rect.h = ctx.screen_size.y
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
	// pre-order traversal
	// We know that at this point the only element left is the root element
	draw_element(ctx, ctx.root_element)
}

draw_rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	push(&ctx.command_stack, Command_Rect{rect, color})
}

draw_text :: proc(ctx: ^Context, x, y: f32, str: string) {
	push(&ctx.command_stack, Command_Text{x, y, str})
}

draw_image :: proc(ctx: ^Context, x, y, w, h: f32, data: rawptr) {
	push(&ctx.command_stack, Command_Image{x, y, w, h, data})
}

// TODO(Thomas): Hardcoded layout / styling
button :: proc(ctx: ^Context, id: string) -> Comm {
	element, open_ok := open_element(
		ctx,
		id,
		{
			layout = {sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}}},
			background_color = {255, 255, 255, 255},
			capability_flags = {.Background},
		},
	)
	if open_ok {
		close_element(ctx)
	}
	comm := comm_from_element(ctx, element)
	return comm
}
