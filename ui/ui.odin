package ui

import "core:log"
import "core:mem"
import "core:strings"
import textedit "core:text/edit"

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

Context :: struct {
	persistent_allocator: mem.Allocator,
	frame_allocator:      mem.Allocator,
	command_stack:        Stack(Command, COMMAND_STACK_SIZE),
	element_stack:        Stack(^UI_Element, ELEMENT_STACK_SIZE),
	current_parent:       ^UI_Element,
	root_element:         ^UI_Element,
	input:                Input,
	element_cache:        map[UI_Key]^UI_Element,
	frame_index:          u64,
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
		{color = Color{128, 128, 128, 255}, sizing = {{kind = .Fit}, {kind = .Fit}}},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)
	ctx.root_element = root_element

}

end :: proc(ctx: ^Context) {

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	grow_child_elements_for_axis(ctx.root_element, .X)
	grow_child_elements_for_axis(ctx.root_element, .Y)

	shrink_child_elements_for_axis(ctx.root_element, .X)
	shrink_child_elements_for_axis(ctx.root_element, .Y)

	calculate_positions(ctx.root_element)

	draw_all_elements(ctx)
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
		draw_text(ctx, i32(element.position.x), i32(element.position.y), element.text_config.data)
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
