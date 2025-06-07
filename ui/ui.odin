package ui

import "core:mem"

COMMAND_STACK_SIZE :: #config(SUI_COMMAND_STACK_SIZE, 100)
ELEMENT_STACK_SIZE :: #config(SUI_ELEMENT_STACK_SIZE, 64)
PARENT_STACK_SIZE :: #config(SUI_PARENT_STACK_SIZE, 64)
STYLE_STACK_SIZE :: #config(SUI_STYLE_STACK_SIZE, 64)
CHILD_LAYOUT_AXIS_STACK_SIZE :: #config(SUI_CHILD_LAYOUT_AXIS_STACK_SIZE, 64)
MAX_TEXT_STORE :: #config(SUI_MAX_TEXT_STORE, 1024)
CHAR_WIDTH :: #config(SUI_CHAR_WIDTH, 14)
CHAR_HEIGHT :: #config(SUI_CHAR_HEIGHT, 24)

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

Rect :: struct {
	x, y, w, h: i32,
}

Command :: union {
	Command_Rect,
	Command_Text,
}

Command_Rect :: struct {
	rect:  Rect,
	color: Color,
}

Command_Text :: struct {
	x, y: i32,
	str:  string,
}

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
	advance_width: f32,
	left_bearing:  f32,
	width:         f32,
	height:        f32,
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

init :: proc(ctx: ^Context, persistent_allocator: mem.Allocator, frame_allocator: mem.Allocator) {
	ctx^ = {} // zero memory
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator

	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)
}

deinit :: proc(ctx: ^Context) {
}

begin :: proc(ctx: ^Context) {
	clear(&ctx.command_stack)

	// Open the root element
	root_open_ok := open_element(
		ctx,
		"root",
		{color = Color{128, 128, 128, 255}, layout = {sizing = {{kind = .Fit}, {kind = .Fit}}}},
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
	// Grow sizing widths
	grow_child_elements_for_axis(ctx.root_element, .X)
	// Shrink sizing widths
	shrink_child_elements_for_axis(ctx.root_element, .X)

	// Wrap text
	wrap_text(ctx, ctx.root_element, context.temp_allocator)
	defer free_all(context.temp_allocator)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Grow sizing heights
	grow_child_elements_for_axis(ctx.root_element, .Y)
	// Shrink sizing heights
	shrink_child_elements_for_axis(ctx.root_element, .Y)

	calculate_positions(ctx.root_element)

	draw_all_elements(ctx)

	free_all(ctx.frame_allocator)
}

draw_element :: proc(ctx: ^Context, element: ^UI_Element) {
	if element == nil {
		return
	}

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

	if element.kind == .Text {
		for line, idx in element.text_lines {
			draw_text(
				ctx,
				i32(element.position.x),
				i32(element.position.y) + i32(idx) * line.height,
				line.text,
			)
		}
	}

	for child in element.children {
		draw_element(ctx, child)
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

draw_text :: proc(ctx: ^Context, x, y: i32, str: string) {
	push(&ctx.command_stack, Command_Text{x, y, str})
}
