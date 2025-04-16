package ui

import "core:strings"
import textedit "core:text/edit"

COMMAND_LIST_SIZE :: #config(SUI_COMMAND_LIST_SIZE, 100)
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
	hot_item:    u64,
	active_item: u64,
	kbd_item:    u64,
	last_widget: u64,
}

Style :: struct {
	scrollbar_size:    i32,
	scroll_thumb_size: i32,
	colors:            [Color_Type]Color,
}

Context :: struct {
	command_list: Stack(Command, COMMAND_LIST_SIZE),
	ui_state:     UI_State,
	style:        Style,
	input:        Input,
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

init :: proc(ctx: ^Context) {
	ctx^ = {} // zero memory
	ctx.style = default_style
	ctx.input.text = strings.builder_from_bytes(ctx.input._text_store[:])
	ctx.input.textbox_state.builder = &ctx.input.text
}

draw_rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	push(&ctx.command_list, Command_Rect{rect, color})
}

draw_text :: proc(ctx: ^Context, x, y: i32, str: string) {
	push(&ctx.command_list, Command_Text{x, y, str})
}

button :: proc(ctx: ^Context, id_key: string, rect: Rect) -> bool {
	id := hash_key(id_key)
	left_click := is_mouse_down(ctx^, .Left)

	// Check whether the button should be hot
	if intersect_rect(ctx^, rect) {
		ctx.ui_state.hot_item = id
		if ctx.ui_state.active_item == 0 && left_click {
			ctx.ui_state.active_item = id
		}
	}

	// If no widget has keyboard focus, take it
	if ctx.ui_state.kbd_item == 0 {
		ctx.ui_state.kbd_item = id
	}

	// If we have keyboard focus, show it
	if ctx.ui_state.kbd_item == id {
		draw_rect(ctx, Rect{rect.x - 6, rect.y - 6, 84, 68}, ctx.style.colors[.Selection_BG])
	}

	// draw button
	draw_rect(ctx, Rect{rect.x + 8, rect.y + 8, rect.w, rect.h}, ctx.style.colors[.Button_Shadow])
	if ctx.ui_state.hot_item == id {
		if ctx.ui_state.active_item == id {
			// Button is both 'hot' and 'active'
			draw_rect(
				ctx,
				Rect{rect.x + 2, rect.y + 2, rect.w, rect.h},
				ctx.style.colors[.Button_Active],
			)
		} else {
			// Button is merely 'hot'
			draw_rect(ctx, rect, ctx.style.colors[.Button_Hot])
		}
	} else {
		if ctx.ui_state.active_item == id {
			draw_rect(
				ctx,
				Rect{rect.x + 2, rect.y + 2, rect.w, rect.h},
				ctx.style.colors[.Button_Active],
			)
		} else {
			draw_rect(ctx, rect, ctx.style.colors[.Button])
		}
	}

	// If we have keyboard focus, we'll need to process the keys
	if ctx.ui_state.kbd_item == id {
		key := get_key_pressed(ctx^)
		if key == .Tab {
			// If tab is pressed, lose keyboard focus.
			// Next widget will grab the focus.
			ctx.ui_state.kbd_item = 0

			// If shift was also pressed, we want to move focus
			// to the previous widget instead.
			if ctx.input.keymod_down_bits <= KMOD_SHIFT && ctx.input.keymod_down_bits != {} {
				ctx.ui_state.kbd_item = ctx.ui_state.last_widget
			}

			// Also clear the key so that next widget
			// won't process it
			ctx.input.key_pressed_bits = {}
		} else if key == .Return {
			// Had keyboard focus, received return,
			// so we'll act as if we were clicked.
			return true
		}
	}

	ctx.ui_state.last_widget = id


	// If button is hot and active, but mouse button is not
	// down, the user must have clicked the button
	if !left_click && ctx.ui_state.hot_item == id && ctx.ui_state.active_item == id {
		ctx.ui_state.kbd_item = id
		return true
	}

	return false
}

// Simple scroll bar widget
slider :: proc(ctx: ^Context, id_key: string, x, y, max: i32, value: ^i32) -> bool {
	id := hash_key(id_key)

	// Calculate mouse cursor's relative y offset
	start_y: i32 = 16
	length: i32 = 256
	y_pos := ((length - start_y) * value^) / max

	left_click := is_mouse_down(ctx^, .Left)

	// Check for hotness
	if intersect_rect(ctx^, Rect{x + 8, y + 8, start_y, length - 1}) {
		ctx.ui_state.hot_item = id
		if ctx.ui_state.active_item == 0 && left_click {
			ctx.ui_state.active_item = id
		}
	}

	// If no widget has keyboard focus, take it
	if ctx.ui_state.kbd_item == 0 {
		ctx.ui_state.kbd_item = id
	}

	// If we have keyboard focus, show it
	if ctx.ui_state.kbd_item == id {
		draw_rect(ctx, Rect{x - 4, y - 4, 40, 280}, ctx.style.colors[.Selection_BG])
	}

	// Render the scrollbar
	scroll_bar_width: i32 = 32
	draw_rect(ctx, Rect{x, y, scroll_bar_width, length + start_y}, ctx.style.colors[.Scroll_Base])

	thumb_width: i32 = 16
	if ctx.ui_state.active_item == id || ctx.ui_state.hot_item == id {
		draw_rect(
			ctx,
			Rect{x + 8, y + 8 + y_pos, thumb_width, thumb_width},
			ctx.style.colors[.Scroll_Thumb_Hot],
		)
	} else {
		draw_rect(
			ctx,
			Rect{x + 8, y + 8 + y_pos, thumb_width, thumb_width},
			ctx.style.colors[.Scroll_Thumb],
		)
	}

	// If we have keyboard focus, we'll need to process the keys
	if ctx.ui_state.kbd_item == id {
		key := get_key_pressed(ctx^)
		#partial switch key {
		case .Tab:
			// If tab is pressed, lose keyboard focus
			// Next widget will grab the focus.
			ctx.ui_state.kbd_item = 0

			// If shift was also pressed, we want to move focus
			// to the previous widget instead
			if ctx.input.keymod_down_bits <= KMOD_SHIFT && ctx.input.keymod_down_bits != {} {
				ctx.ui_state.kbd_item = ctx.ui_state.last_widget
			}
			// Also clear the key so that next widget
			// won't process it
			ctx.input.key_pressed_bits = {}
		case .Up:
			// Slide value up (if not at zero)
			if value^ > 0 {
				value^ -= 1
				return true
			}
		case .Down:
			// Slide value down (if not at max)
			if value^ < max {
				value^ += 1
				return true
			}
		}
	}

	// If widget is hot and active, but mouse button is not 
	// down, the user must have clicked the widget; give it
	// keyboard focus
	if left_click && ctx.ui_state.hot_item == id && ctx.ui_state.active_item == id {
		ctx.ui_state.kbd_item = id
	}

	ctx.ui_state.last_widget = id

	// Update widget value
	if ctx.ui_state.active_item == id {
		mouse_pos := ctx.input.mouse_pos.y - (y + 8)
		if mouse_pos < 0 {
			mouse_pos = 0
		} else if mouse_pos > 255 {
			mouse_pos = 255
		}

		v := (mouse_pos * max) / 255
		if v != value^ {
			value^ = v
			return true
		}
	}

	return false
}

text_field :: proc(
	ctx: ^Context,
	id_key: string,
	rect: Rect,
	text_buf: []u8,
	text_len: ^int,
) -> bool {
	id := hash_key(id_key)
	left_click := is_mouse_down(ctx^, .Left)

	// Check for hotness
	if intersect_rect(ctx^, Rect{rect.x + 8, rect.y + 8, rect.w, rect.h}) {
		ctx.ui_state.hot_item = id
		if ctx.ui_state.active_item == 0 && left_click {
			ctx.ui_state.active_item = id
		}
	}

	// If no widget has keyboard focus, take it
	if ctx.ui_state.kbd_item == 0 {
		ctx.ui_state.kbd_item = id
	}

	// If we have keyboard focus, show it
	if ctx.ui_state.kbd_item == id {
		draw_rect(
			ctx,
			Rect{rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12},
			ctx.style.colors[.Selection_BG],
		)
	}

	// Render the text field
	if ctx.ui_state.active_item == id || ctx.ui_state.hot_item == id {
		draw_rect(
			ctx,
			Rect{rect.x - 4, rect.y - 4, rect.w + 8, rect.h + 8},
			ctx.style.colors[.Base_Hot],
		)
	} else {
		draw_rect(
			ctx,
			Rect{rect.x - 4, rect.y - 4, rect.w + 8, rect.h + 8},
			ctx.style.colors[.Base],
		)
	}

	if ctx.ui_state.kbd_item == id {
		builder := strings.builder_from_bytes(text_buf)
		non_zero_resize(&builder.buf, text_len^)
		ctx.input.textbox_state.builder = &builder

		if strings.builder_len(ctx.input.text) > 0 {
			if textedit.input_text(&ctx.input.textbox_state, strings.to_string(ctx.input.text)) >
			   0 {
				text_len^ = strings.builder_len(builder)
			}
		}


		key := get_key_pressed(ctx^)
		#partial switch key {
		case .Tab:
			// If tab is pressed, lose keyboard focus.
			// Next widget will grab the focus.
			ctx.ui_state.kbd_item = 0

			// If shift was also pressed, we want to move focus
			// to the previous widget instead
			if ctx.input.keymod_down_bits <= KMOD_SHIFT && ctx.input.keymod_down_bits != {} {
				ctx.ui_state.kbd_item = ctx.ui_state.last_widget
			}

			// Also clear the key so that next widget
			// won't process it
			ctx.input.key_pressed_bits = {}

		case .Backspace:
			move: textedit.Translation =
				textedit.Translation.Word_Left if .Left_Ctrl in ctx.input.key_down_bits else textedit.Translation.Left
			textedit.delete_to(&ctx.input.textbox_state, move)
			text_len^ = strings.builder_len(builder)
		}
	}

	ctx.input.textbox_state.selection[0] = text_len^
	draw_text(ctx, rect.x, rect.y, string(text_buf[:text_len^]))

	// If widget is hot and active, but mouse button is not 
	// down, the user must have clicked the widget; give it
	// keyboard focus
	if is_mouse_down(ctx^, .Left) &&
	   ctx.ui_state.hot_item == id &&
	   ctx.ui_state.active_item == id {
		ctx.ui_state.kbd_item = id
	}

	ctx.ui_state.last_widget = id

	return true
}

begin :: proc(ctx: ^Context) {
	ctx.ui_state.hot_item = 0
	ctx.command_list.idx = -1
}

end :: proc(ctx: ^Context) {
	if .Left != get_mouse_down(ctx^) {
		ctx.ui_state.active_item = 0
	} else {
		if ctx.ui_state.active_item == 0 {
			// TODO(Thomas): This has to change but still keep the original effect
			// This will only work because its very unlikely that we get hashes that will
			// result into 1337 here, but we're not guaranteed.
			//ctx.ui_state.active_item = -1
			ctx.ui_state.active_item = 1337
		}
	}
	// If no widget grabbed tab, clear focus
	key := get_key_pressed(ctx^)
	if key == .Tab {
		ctx.ui_state.kbd_item = 0
	}

	// clear input
	ctx.input.key_pressed_bits = {}
	strings.builder_reset(&ctx.input.text)
}
