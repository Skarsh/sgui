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

	// Load font atlas
	surface := sdl.LoadBMP("data/font14x24.bmp")
	if surface == nil {
		log.error("Failed to load font atlas:", sdl.GetError())
		return
	}
	defer sdl.FreeSurface(surface)

	// Set color key to make black (0) transparent
	sdl.SetColorKey(surface, 1, 0)

	font_atlas := sdl.CreateTextureFromSurface(g_renderer, surface)
	if font_atlas == nil {
		log.error("Failed to create texture:", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(font_atlas)

	ctx := ui.Context{}
	ui.init(&ctx)

	app_state := App_State {
		ctx            = ctx,
		font_atlas     = font_atlas,
		slider_value_1 = i32(ctx.style.colors[.Window_BG].r),
		slider_value_2 = i32(ctx.style.colors[.Window_BG].g),
		slider_value_3 = i32(ctx.style.colors[.Window_BG].b),
		text_buf       = make([]u8, 1024),
		text_len       = 0,
	}

	for running {
		process_input(&app_state)

		sdl.SetRenderDrawColor(
			g_renderer,
			u8(app_state.slider_value_1),
			u8(app_state.slider_value_2),
			u8(app_state.slider_value_3),
			255,
		)
		sdl.RenderClear(g_renderer)

		build_and_render_ui(&app_state)
		//build_and_render_ui_new(&app_state)

		sdl.RenderPresent(g_renderer)

		sdl.Delay(10)
	}
}

sdl_key_to_ui_key :: proc(sdl_key: sdl.Keycode) -> ui.Key {
	key := ui.Key.Unknown
	// TODO(Thomas): Complete more of this switch
	#partial switch sdl_key {
	case .ESCAPE:
		key = ui.Key.Escape
	case .TAB:
		key = ui.Key.Tab
	case .RETURN:
		key = ui.Key.Return
	case .UP:
		key = ui.Key.Up
	case .DOWN:
		key = ui.Key.Down
	case .LSHIFT:
		key = ui.Key.Left_Shift
	case .RSHIFT:
		key = ui.Key.Right_Shift
	case .BACKSPACE:
		key = ui.Key.Backspace
	}
	return key
}

sdl_keymod_to_ui_keymod :: proc(sdl_key_mod: sdl.Keymod) -> ui.Keymod_Set {
	key_mod := ui.KMOD_NONE

	// TODO(Thomas): Do this for the complete set of modifiers
	if .LSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_LSHIFT
	} else if .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_RSHIFT
	} else if .LSHIFT in sdl_key_mod && .RSHIFT in sdl_key_mod {
		key_mod = ui.KMOD_SHIFT
	}

	return key_mod
}

render_text :: proc(
	renderer: ^sdl.Renderer,
	font_atlas: ^sdl.Texture,
	x, y: i32,
	char_width: i32,
	char_height: i32,
	text: string,
) {

	src_rect := sdl.Rect{}
	dst_rect := sdl.Rect{x, y, char_width, char_height}

	for c in text {
		src_rect.x = 0
		src_rect.y = (i32(c) - 32) * char_height
		src_rect.w = char_width
		src_rect.h = char_height

		sdl.RenderCopy(renderer, font_atlas, &src_rect, &dst_rect)
		dst_rect.x += char_width
	}
}

App_State :: struct {
	ctx:            ui.Context,
	font_atlas:     ^sdl.Texture,
	slider_value_1: i32,
	slider_value_2: i32,
	slider_value_3: i32,
	text_buf:       []u8,
	text_len:       int,
}


build_and_render_ui :: proc(app_state: ^App_State) {

	ui.begin(&app_state.ctx)
	ui.button(&app_state.ctx, "one", ui.Rect{50, 50, 64, 48})
	ui.button(&app_state.ctx, "two", ui.Rect{150, 50, 64, 48})
	ui.button(&app_state.ctx, "three", ui.Rect{50, 150, 64, 48})

	ui.slider(&app_state.ctx, "red", 500, 40, 255, &app_state.slider_value_1)
	ui.slider(&app_state.ctx, "green", 550, 40, 255, &app_state.slider_value_2)
	ui.slider(&app_state.ctx, "blue", 600, 40, 255, &app_state.slider_value_3)

	ui.text_field(
		&app_state.ctx,
		"texty",
		ui.Rect{50, 400, 500, 24},
		app_state.text_buf,
		&app_state.text_len,
	)

	render_draw_commands(app_state)

	ui.end(&app_state.ctx)
}

render_draw_commands :: proc(app_state: ^App_State) {

	commands := [ui.COMMAND_LIST_SIZE]ui.Command{}

	idx := 0
	for command, ok := ui.pop(&app_state.ctx.command_list);
	    ok;
	    command, ok = ui.pop(&app_state.ctx.command_list) {
		commands[idx] = command
		idx += 1
	}

	#reverse for command in commands {
		switch val in command {
		case ui.Command_Rect:
			rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}
			sdl.SetRenderDrawColor(g_renderer, val.color.r, val.color.g, val.color.b, val.color.a)
			sdl.RenderDrawRect(g_renderer, &rect)
			sdl.RenderFillRect(g_renderer, &rect)
		case ui.Command_Text:
			render_text(
				g_renderer,
				app_state.font_atlas,
				val.x,
				val.y,
				ui.CHAR_WIDTH,
				ui.CHAR_HEIGHT,
				val.str,
			)
		}
	}
}

build_and_render_ui_new :: proc(app_state: ^App_State) {

	ui.begin_new(&app_state.ctx)

	ui.button_new(&app_state.ctx, "new button")

	render_draw_commands(app_state)

	ui.end_new(&app_state.ctx)
}

process_input :: proc(app_state: ^App_State) {
	// Process input
	event := sdl.Event{}
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .MOUSEMOTION:
			ui.handle_mouse_move(&app_state.ctx, event.motion.x, event.motion.y)
		case .MOUSEBUTTONDOWN:
			btn: ui.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			ui.handle_mouse_down(&app_state.ctx, event.motion.x, event.motion.y, btn)
		case .MOUSEBUTTONUP:
			btn: ui.Mouse
			switch event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			ui.handle_mouse_up(&app_state.ctx, event.motion.x, event.motion.y, btn)
		case .KEYUP:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_up(&app_state.ctx, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(&app_state.ctx, keymod)

			#partial switch event.key.keysym.sym {
			case .ESCAPE:
				running = false
			}
		case .KEYDOWN:
			key := sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_down(&app_state.ctx, key)
			keymod := sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(&app_state.ctx, keymod)
		case .TEXTINPUT:
			text := string(cstring(&event.text.text[0]))
			ui.handle_text(&app_state.ctx, text)
		case .QUIT:
			running = false
		}
	}
}
