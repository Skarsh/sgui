package ui

import "core:mem"
import "core:strings"
import textedit "core:text/edit"

COMMAND_LIST_SIZE :: #config(SUI_COMMAND_LIST_SIZE, 100)
PARENT_LIST_SIZE :: #config(SUI_PARENT_LIST_SIZE, 64)
MAX_TEXT_STORE :: #config(SUI_MAX_TEXT_STORE, 1024)
CHAR_WIDTH :: #config(SUI_CHAR_WIDTH, 14)
CHAR_HEIGHT :: #config(SUI_CHAR_HEIGHT, 24)


Vector2i32 :: [2]i32

Color_Type :: enum u32 {
	Text,
	Selection_BG,
	Window_BG,
	Button,
	Button_Hot,
	Button_Active,
	Button_Shadow,
	Base,
	Base_Hot,
	Base_Active,
	Scroll_Base,
	Scroll_Thumb,
	Scroll_Thumb_Hot,
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

Style :: struct {
	scrollbar_size:    i32,
	scroll_thumb_size: i32,
	colors:            [Color_Type]Color,
}

Context :: struct {
	persistent_allocator: mem.Allocator,
	frame_allocator:      mem.Allocator,
	command_list:         Stack(Command, COMMAND_LIST_SIZE),
	parent_list:          Stack(^Widget, PARENT_LIST_SIZE),
	root_widget:          ^Widget,
	ui_state:             UI_State,
	current_parent:       ^Widget,
	style:                Style,
	input:                Input,
	widget_cache:         map[UI_Key]^Widget,
	frame_index:          u64,
}

default_style := Style {
	scrollbar_size = 12,
	scroll_thumb_size = 8,
	colors = {
		.Text = {230, 230, 230, 255},
		.Selection_BG = {90, 90, 90, 255},
		.Window_BG = {50, 50, 50, 255},
		.Button = {75, 75, 75, 255},
		.Button_Hot = {95, 95, 95, 255},
		.Button_Active = {115, 115, 115, 255},
		.Button_Shadow = {0, 0, 0, 255},
		.Base = {30, 30, 30, 255},
		.Base_Hot = {35, 35, 35, 255},
		.Base_Active = {40, 40, 40, 255},
		.Scroll_Base = {43, 43, 43, 255},
		.Scroll_Thumb = {30, 30, 30, 255},
		.Scroll_Thumb_Hot = {95, 95, 95, 255},
	},
}

init :: proc(ctx: ^Context, persistent_allocator: mem.Allocator, frame_allocator: mem.Allocator) {
	ctx^ = {} // zero memory
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.style = default_style
	ctx.input.text = strings.builder_from_bytes(ctx.input._text_store[:])
	ctx.input.textbox_state.builder = &ctx.input.text

	ctx.current_parent = nil

	// TODO(Thomas): Allocate from passed in allocator
	ctx.widget_cache = make(map[UI_Key]^Widget, persistent_allocator)
}

draw_rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	push(&ctx.command_list, Command_Rect{rect, color})
}

draw_text :: proc(ctx: ^Context, x, y: i32, str: string) {
	push(&ctx.command_list, Command_Text{x, y, str})
}
