package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"

import sdl "vendor:sdl2"

import "ui"

g_window: ^sdl.Window
g_renderer: ^sdl.Renderer

// This example uses SDL2, but the immediate mode ui library should be 
// rendering and windowing agnostic 

running := true
main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	logger := log.create_console_logger(log.Level.Info)
	context.logger = logger
	defer log.destroy_console_logger(logger)

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

	persistent_arena := virtual.Arena{}
	persistent_arena_buffer := make([]u8, 100 * 1024)
	persistent_arena_alloc_err := virtual.arena_init_buffer(
		&persistent_arena,
		persistent_arena_buffer,
	)
	assert(persistent_arena_alloc_err == .None)
	persistent_arena_allocator := virtual.arena_allocator(&persistent_arena)
	defer free_all(persistent_arena_allocator)
	defer delete(persistent_arena_buffer)

	frame_arena := virtual.Arena{}
	frame_arena_buffer := make([]u8, 100 * 1024)
	frame_arena_alloc_err := virtual.arena_init_buffer(&frame_arena, frame_arena_buffer)
	assert(frame_arena_alloc_err == .None)
	frame_arena_allocator := virtual.arena_allocator(&frame_arena)
	defer free_all(frame_arena_allocator)
	defer delete(frame_arena_buffer)

	ui.init(&ctx, persistent_arena_allocator, frame_arena_allocator)

	// TODO(Thomas): When suitable, this should come from a fixed size buffer allocator
	// or something.
	text_buf := make([]u8, 1024)
	defer delete(text_buf)
	app_state := App_State {
		ctx        = ctx,
		font_atlas = font_atlas,
		text_buf   = text_buf,
		text_len   = 0,
	}

	for running {
		process_input(&app_state)

		sdl.SetRenderDrawColor(g_renderer, 128, 128, 128, 255)
		sdl.RenderClear(g_renderer)

		build_and_render_ui(&app_state)

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
	ctx:        ui.Context,
	font_atlas: ^sdl.Texture,
	text_buf:   []u8,
	text_len:   int,
}

render_draw_commands :: proc(app_state: ^App_State) {

	commands := [ui.COMMAND_STACK_SIZE]ui.Command{}

	idx := 0
	for command, ok := ui.pop(&app_state.ctx.command_stack);
	    ok;
	    command, ok = ui.pop(&app_state.ctx.command_stack) {
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

build_and_render_ui :: proc(app_state: ^App_State) {

	ui.begin(&app_state.ctx)

	root, root_ok := ui.widget_make(&app_state.ctx, "root")
	app_state.ctx.root_widget = root
	assert(root_ok)
	ui.push_parent(&app_state.ctx, root)

	ui.push_color(&app_state.ctx, .Base, ui.Color{255, 0, 0, 255})
	button_panel_comm := ui.button_panel(&app_state.ctx, "button_panel")
	ui.pop_color(&app_state.ctx)

	ui.push_parent(&app_state.ctx, button_panel_comm.widget)

	ui.push_color(&app_state.ctx, .Base, ui.Color{255, 255, 0, 255})
	comm_button_1 := ui.button(&app_state.ctx, "button_1")
	ui.pop_color(&app_state.ctx)

	if comm_button_1.held {
		log.infof("%s held: ", comm_button_1.widget.string)
	}

	comm_button_2 := ui.button(&app_state.ctx, "button_2")
	if comm_button_2.held {
		log.infof("%s held: ", comm_button_2.widget.string)
	}

	// Pop button panel
	ui.pop_parent(&app_state.ctx)

	// Pop root
	ui.pop_parent(&app_state.ctx)

	ui.end(&app_state.ctx)

	render_draw_commands(app_state)
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
