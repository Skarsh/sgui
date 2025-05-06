package ui

import "core:mem"
import "core:strings"
import textedit "core:text/edit"

COMMAND_STACK_SIZE :: #config(SUI_COMMAND_STACK_SIZE, 100)
PARENT_STACK_SIZE :: #config(SUI_PARENT_STACK_SIZE, 64)
STYLE_STACK_SIZE :: #config(SUI_STYLE_STACK_SIZE, 64)
CHILD_LAYOUT_AXIS_STACK_SIZE :: #config(SUI_CHILD_LAYOUT_AXIS_STACK_SIZE, 64)
MAX_TEXT_STORE :: #config(SUI_MAX_TEXT_STORE, 1024)
CHAR_WIDTH :: #config(SUI_CHAR_WIDTH, 14)
CHAR_HEIGHT :: #config(SUI_CHAR_HEIGHT, 24)

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

UI_State :: struct {
	hot_item:    UI_Key,
	active_item: UI_Key,
	kbd_item:    UI_Key,
	last_widget: UI_Key,
}

Color_Style :: [Color_Type]Color

Context :: struct {
	persistent_allocator:    mem.Allocator,
	frame_allocator:         mem.Allocator,
	command_stack:           Stack(Command, COMMAND_STACK_SIZE),
	parent_stack:            Stack(^Widget, PARENT_STACK_SIZE),
	style_stack:             Stack(Color_Style, STYLE_STACK_SIZE),
	child_layout_axis_stack: Stack(Axis2, CHILD_LAYOUT_AXIS_STACK_SIZE),
	root_widget:             ^Widget,
	ui_state:                UI_State,
	current_parent:          ^Widget,
	input:                   Input,
	widget_cache:            map[UI_Key]^Widget,
	frame_index:             u64,
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
	ctx.input.text = strings.builder_from_bytes(ctx.input._text_store[:])
	ctx.input.textbox_state.builder = &ctx.input.text

	// TODO(Thomas): Ideally we would like to not having to initialize
	// the stacks like this. This has already caused issues.
	ctx.command_stack = create_stack(Command, COMMAND_STACK_SIZE)
	ctx.parent_stack = create_stack(^Widget, PARENT_STACK_SIZE)
	ctx.style_stack = create_stack(Color_Style, STYLE_STACK_SIZE)
	ctx.child_layout_axis_stack = create_stack(Axis2, CHILD_LAYOUT_AXIS_STACK_SIZE)

	ctx.current_parent = nil

	// TODO(Thomas): Allocate from passed in allocator
	ctx.widget_cache = make(map[UI_Key]^Widget, persistent_allocator)
}

draw_rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	push(&ctx.command_stack, Command_Rect{rect, color})
}

draw_text :: proc(ctx: ^Context, x, y: i32, str: string) {
	push(&ctx.command_stack, Command_Text{x, y, str})
}

push_color :: proc(ctx: ^Context, color_type: Color_Type, color: Color) -> bool {
	colors := default_color_style
	colors[color_type] = color
	return push(&ctx.style_stack, colors)
}

pop_color :: proc(ctx: ^Context) -> (Color_Style, bool) {
	return pop(&ctx.style_stack)
}

push_child_layout_axis :: proc(ctx: ^Context, axis: Axis2) -> bool {
	return push(&ctx.child_layout_axis_stack, axis)
}

pop_child_layout_axis :: proc(ctx: ^Context) -> (Axis2, bool) {
	return pop(&ctx.child_layout_axis_stack)
}
