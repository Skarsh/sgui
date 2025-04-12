package ui

import "core:log"

COMMAND_LIST_SIZE :: #config(SUI_COMMAND_LIST_SIZE, 100)

Vector2i32 :: [2]i32

Color :: struct {
	r, g, b, a: u8,
}

Rect :: struct {
	x, y, w, h: i32,
}

Command :: union {
	Command_Rect,
}

Command_Rect :: struct {
	rect:  Rect,
	color: Color,
}

UI_State :: struct {
	hot_item:    i32,
	active_item: i32,
	kbd_item:    i32,
	key_entered: Key,
	key_mod:     Keymod_Set,
	last_widget: i32,
}

intersect_rect :: proc(ctx: Context, rect: Rect) -> bool {
	if ctx.input.mouse_pos.x < rect.x ||
	   ctx.input.mouse_pos.y < rect.y ||
	   ctx.input.mouse_pos.x >= rect.x + rect.w ||
	   ctx.input.mouse_pos.y >= rect.y + rect.h {
		return false
	}
	return true
}

Context :: struct {
	command_list: Stack(Command, COMMAND_LIST_SIZE),
	ui_state:     UI_State,
	input:        Input,
}

draw_rect :: proc(ctx: ^Context, rect: Rect, color: Color) {
	push(&ctx.command_list, Command_Rect{rect, color})
}

button :: proc(ctx: ^Context, id: i32, rect: Rect) -> bool {
	left_click := .Left in ctx.input.mouse_down_bits

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
		draw_rect(ctx, Rect{rect.x - 6, rect.y - 6, 84, 68}, Color{255, 0, 0, 255})
	}

	// draw button
	draw_rect(ctx, Rect{rect.x + 8, rect.y + 8, rect.w, rect.h}, Color{0, 0, 0, 255})
	if ctx.ui_state.hot_item == id {
		if ctx.ui_state.active_item == id {
			// Button is both 'hot' and 'active'
			draw_rect(ctx, Rect{rect.x + 2, rect.y + 2, rect.w, rect.h}, Color{255, 255, 255, 255})
		} else {
			// Button is merely 'hot'
			draw_rect(ctx, rect, Color{255, 255, 255, 255})
		}
	} else {
		// button is not hot, but may be active
		draw_rect(ctx, rect, Color{128, 128, 128, 255})
	}

	// If we have keyboard focus, we'll need to process the keys
	if ctx.ui_state.kbd_item == id {
		#partial switch ctx.ui_state.key_entered {
		case .Tab:
			// If tab is pressed, lose keyboard focus.
			// Next widget will grab the focus.
			ctx.ui_state.kbd_item = 0

			// If shift was also pressed, we want to move focus
			// to the previous widget instead.
			if ctx.ui_state.key_mod == KMOD_SHIFT {
				ctx.ui_state.kbd_item = ctx.ui_state.last_widget
			}

			// Also clear the key so that next widget
			// won't process it
			ctx.ui_state.key_entered = .Unknown
		case .Return:
			// Had keyboard focus, received return,
			// so we'll act as if we were clicked.
			return true
		}
	}

	ctx.ui_state.last_widget = id


	// If button is hot and active, but mouse button is not
	// down, the user must have clicked the button
	if !left_click && ctx.ui_state.hot_item == id && ctx.ui_state.active_item == id {
		return true
	}

	return false
}

// Simple scroll bar widget
slider :: proc(ctx: ^Context, id, x, y, max: i32, value: ^i32) -> bool {
	// Calculate mouse cursor's relative y offset
	start_y: i32 = 16
	length: i32 = 256
	y_pos := ((length - start_y) * value^) / max

	left_click := .Left in ctx.input.mouse_down_bits

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
		draw_rect(ctx, Rect{x - 4, y - 4, 40, 280}, Color{255, 0, 0, 255})
	}

	// Render the scrollbar
	scroll_bar_width: i32 = 32
	draw_rect(ctx, Rect{x, y, scroll_bar_width, length + start_y}, Color{0x77, 0x77, 0x77, 0xff})

	thumb_width: i32 = 16
	if ctx.ui_state.active_item == id || ctx.ui_state.hot_item == id {
		draw_rect(
			ctx,
			Rect{x + 8, y + 8 + y_pos, thumb_width, thumb_width},
			Color{0xff, 0xff, 0xff, 0xff},
		)
	} else {
		draw_rect(
			ctx,
			Rect{x + 8, y + 8 + y_pos, thumb_width, thumb_width},
			Color{0xaa, 0xaa, 0xaa, 0xff},
		)
	}

	// If we have keyboard focus, we'll need to process the keys
	if ctx.ui_state.kbd_item == id {
		#partial switch ctx.ui_state.key_entered {
		case .Tab:
			// If tab is pressed, lose keyboard focus
			// Next widget will grab the focus.
			ctx.ui_state.kbd_item = 0

			// If shift was also pressed, we want to move focus
			// to the previous widget instead
			if ctx.ui_state.key_mod == KMOD_SHIFT {
				ctx.ui_state.kbd_item = ctx.ui_state.last_widget
			}
			// Also clear the key so that next widget
			// won't process it
			ctx.ui_state.key_entered = .Unknown
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

begin :: proc(ctx: ^Context) {
	ctx.ui_state.hot_item = 0
	ctx.command_list.idx = -1
}

end :: proc(ctx: ^Context) {
	left_click := .Left in ctx.input.mouse_down_bits
	if !left_click {
		ctx.ui_state.active_item = 0
	} else {
		if ctx.ui_state.active_item == 0 {
			ctx.ui_state.active_item = -1
		}
	}
	// If no widget grabbed tab, clear focus
	if ctx.ui_state.key_entered == .Tab {
		ctx.ui_state.kbd_item = 0
	}
	ctx.ui_state.key_entered = .Unknown

	// clear input
	ctx.input.key_pressed_bits = {}
}
