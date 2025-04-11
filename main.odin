package main

import "core:log"

import sdl "vendor:sdl2"

import "ui"

g_window: ^sdl.Window
g_renderer: ^sdl.Renderer

// This example uses SDL2, but the immediate mode ui library should be 
// rendering and windowing agnostic 

running := true
main :: proc() {
	context.logger = log.create_console_logger()

	if sdl.Init(sdl.INIT_VIDEO) < 0 {
		log.error("Unable to init SDL: ", sdl.GetError())
		return
	}

	defer sdl.Quit()

	g_window = sdl.CreateWindow(
		"ImGUI",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		640,
		480,
		sdl.WINDOW_SHOWN,
	)

	if g_window == nil {
		log.error("Unable to create window: ", sdl.GetError())
		return
	}

	defer sdl.DestroyWindow(g_window)

	g_renderer = sdl.CreateRenderer(g_window, -1, sdl.RENDERER_ACCELERATED)
	if g_renderer == nil {
		log.error("Unable to create renderer: ", sdl.GetError())
		return
	}
	defer sdl.DestroyRenderer(g_renderer)

	ctx := ui.Context{}

	bg_color: ui.Color
	slider_value_1: i32 = 32
	slider_value_2: i32 = 64
	slider_value_3: i32 = 28
	for running {
		// Process input
		event := sdl.Event{}
		for sdl.PollEvent(&event) {
			#partial switch event.type {
			case .MOUSEMOTION:
				ctx.ui_state.mouse_x = event.motion.x
				ctx.ui_state.mouse_y = event.motion.y
			case .MOUSEBUTTONDOWN:
				ctx.ui_state.mouse_down = true
			case .MOUSEBUTTONUP:
				ctx.ui_state.mouse_down = false
			case .KEYUP:
				#partial switch event.key.keysym.sym {
				case .ESCAPE:
					running = false
				}
			case .KEYDOWN:
				// TODO(Thomas): I really think this should all happen in its own
				// process input or something.
				key := sdlkey_to_own_key(event.key.keysym.sym)
				keymod := sdlkeymod_to_own_keymod(event.key.keysym.mod)
				// TODO(Thomas): At least it should not be set just like this. Just for testing right now.
				ctx.ui_state.key_entered = key
				ctx.ui_state.key_mod = keymod
			case .QUIT:
				running = false
			}
		}

		// Rendering
		// 1. Clear background
		sdl.SetRenderDrawColor(
			g_renderer,
			u8(slider_value_1),
			u8(slider_value_2),
			u8(slider_value_3),
			255,
		)
		sdl.RenderClear(g_renderer)

		// 2. Declare ui
		commands := [ui.COMMAND_LIST_SIZE]ui.Command{}

		ui.begin(&ctx)
		ui.button(&ctx, 2, ui.Rect{50, 50, 64, 48})
		ui.button(&ctx, 3, ui.Rect{150, 50, 64, 48})
		ui.button(&ctx, 4, ui.Rect{50, 150, 64, 48})

		ui.slider(&ctx, 5, 500, 40, 255, &slider_value_1)
		ui.slider(&ctx, 6, 550, 40, 255, &slider_value_2)
		ui.slider(&ctx, 7, 600, 40, 255, &slider_value_3)

		// Assuming stk is already defined and filled with items
		idx := 0
		for command, ok := ui.pop(&ctx.command_list); ok; command, ok = ui.pop(&ctx.command_list) {
			commands[idx] = command
			idx += 1
		}

		#reverse for command in commands {
			switch val in command {
			case ui.Command_Rect:
				rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}
				sdl.SetRenderDrawColor(
					g_renderer,
					val.color.r,
					val.color.g,
					val.color.b,
					val.color.a,
				)
				sdl.RenderDrawRect(g_renderer, &rect)
				sdl.RenderFillRect(g_renderer, &rect)
			}
		}

		ui.end(&ctx)
		sdl.RenderPresent(g_renderer)

		sdl.Delay(10)
	}

}

// TODO(Thomas): Does this belong in the backend or in the ui input layer?
sdlkey_to_own_key :: proc(sdl_key: sdl.Keycode) -> ui.Key {
	key := ui.Key.Unknown
	// TODO(Thomas): Complete more of this switch
	#partial switch sdl_key {
	case .TAB:
		key = ui.Key.Tab
	case .RETURN:
		key = ui.Key.Return
	case .UP:
		key = ui.Key.Up
	case .DOWN:
		key = ui.Key.Down
	}
	return key
}

// TODO(Thomas): Does this belong in the backend or in the ui input layer?
sdlkeymod_to_own_keymod :: proc(sdl_key_mod: sdl.Keymod) -> ui.Keymod {
	key_mod := ui.KMOD_NONE

	if .LSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_LSHIFT
	} else if .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_RSHIFT
	} else if .LSHIFT in sdl_key_mod && .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_SHIFT
	}

	return key_mod
}
