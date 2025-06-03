package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import sdl "vendor:sdl2"
import stbtt "vendor:stb/truetype"

import "ui"

// This example uses SDL2, but the immediate mode ui library should be 
// rendering and windowing agnostic 

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

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

	window := sdl.CreateWindow(
		"ImGUI",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		sdl.WINDOW_SHOWN,
	)

	if window == nil {
		log.error("Unable to create window: ", sdl.GetError())
		return
	}

	renderer := sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED)
	if renderer == nil {
		log.error("Unable to create renderer: ", sdl.GetError())
		return
	}

	font_atlas := Font_Atlas{}
	font_atlas_ok := init_font_atlas(&font_atlas, renderer, "data/font14x24.bmp")
	if !font_atlas_ok {
		log.error("Failed to init font atlas ")
		return
	}


	ctx := ui.Context{}

	persistent_arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&persistent_arena, 100 * mem.Kilobyte)
	assert(arena_err == .None)
	persistent_arena_allocator := virtual.arena_allocator(&persistent_arena)
	defer free_all(persistent_arena_allocator)

	frame_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&frame_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	frame_arena_allocator := virtual.arena_allocator(&frame_arena)
	defer free_all(frame_arena_allocator)

	ui.init(&ctx, persistent_arena_allocator, frame_arena_allocator)
	defer ui.deinit(&ctx)

	font_info := Font_Info{}
	stb_font_ctx := STB_Font_Context {
		font_info = &font_info,
	}

	if !init_stb_font_ctx(&stb_font_ctx, "data/font.ttf") {
		log.error("failed to init stb_font")
		return
	}
	defer deinit_stb_font_ctx(&stb_font_ctx)

	ui.set_text_measurement_callbacks(
		&ctx,
		stb_measure_text,
		stb_measure_glyph,
		stb_get_font_metrics,
		&stb_font_ctx,
	)

	// New font glyph atlas
	font_glyph_atlas := Font_Glyph_Atlas{}
	// TODO(Thomas): Pass in a more suitable allocator here
	init_font_glyph_atlas(&font_glyph_atlas, "data/font.ttf", context.allocator)
	defer deinit_font_glyph_atlas(&font_glyph_atlas)


	app_state := App_State {
		window           = window,
		window_size      = {WINDOW_WIDTH, WINDOW_HEIGHT},
		renderer         = renderer,
		ctx              = ctx,
		font_atlas       = font_atlas,
		font_glyph_atlas = font_glyph_atlas,
		running          = true,
	}
	defer deinit_app_state(&app_state)

	now: u32 = 0
	last: u32 = 0
	for app_state.running {
		last = now
		now = sdl.GetTicks()
		elapsed := now - last
		process_input(&app_state)

		bg_color := ui.default_color_style[.Window_BG]
		sdl.SetRenderDrawColor(renderer, bg_color.r, bg_color.g, bg_color.b, 255)
		sdl.RenderClear(renderer)

		//build_ui(&app_state)
		build_simple_text_ui(&app_state)

		render_draw_commands(&app_state)

		sdl.RenderPresent(renderer)

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

get_text_dimensions :: proc(
	font_info: ^stbtt.fontinfo,
	text: string,
	scale: f32,
	font_size: f32,
) -> (
	width: i32,
	height: i32,
) {

	x: f32 = 0
	max_height: i32 = 0

	for r in text {
		advance, lsb: i32
		stbtt.GetCodepointHMetrics(font_info, r, &advance, &lsb)

		x0, y0, x1, y1: i32
		stbtt.GetCodepointBitmapBox(font_info, r, scale, scale, &x0, &y0, &x1, &y1)

		x += f32(advance) * scale

		char_height := y1 - y0
		if char_height >= max_height {
			max_height = char_height
		}
	}

	return i32(x), max_height + i32(font_size)
}

render_text_by_font :: proc(
	renderer: ^sdl.Renderer,
	font_info: ^stbtt.fontinfo,
	x, y: i32,
	text: string,
	font_size: f32,
) {
	// Get font scale
	scale := stbtt.ScaleForPixelHeight(font_info, font_size)

	text_width, text_height := get_text_dimensions(font_info, text, scale, font_size)

	// allocate bitmap
	bitmap := make([]u8, text_width * text_height, context.temp_allocator)
	defer free_all(context.temp_allocator)

	// Render each character
	x_pos: f32 = 0
	for r in text {
		advance, lsb: i32
		stbtt.GetCodepointHMetrics(font_info, r, &advance, &lsb)

		x0, y0, x1, y1: i32
		stbtt.GetCodepointBitmapBox(font_info, r, scale, scale, &x0, &y0, &x1, &y1)

		y := i32(font_size) + y0
		byte_offset := i32(x_pos) + lsb * i32(scale) + (y * text_width)

		stbtt.MakeCodepointBitmap(
			font_info,
			&bitmap[byte_offset],
			x1 - x0,
			y1 - y0,
			text_width,
			scale,
			scale,
			r,
		)

		x_pos += f32(advance) * scale
	}

	// Create RGBA surface for bitmap,
	rgba_pixels := make([]u8, text_width * text_height * 4, context.temp_allocator)
	for i in 0 ..< text_width * text_height {
		rgba_pixels[i * 4 + 0] = 255 // R
		rgba_pixels[i * 4 + 1] = 255 // G 
		rgba_pixels[i * 4 + 2] = 255 // B
		rgba_pixels[i * 4 + 3] = bitmap[i] // A
	}

	// Create SDL surface and texture
	surface := sdl.CreateRGBSurfaceFrom(
		raw_data(rgba_pixels),
		text_width,
		text_height,
		32,
		text_width * 4,
		0x000000FF,
		0x0000FF00,
		0x00FF0000,
		0xFF000000,
	)

	if surface == nil {
		log.error("Failed to create surface: ", sdl.GetError())
	}
	defer sdl.FreeSurface(surface)

	texture := sdl.CreateTextureFromSurface(renderer, surface)
	if texture == nil {
		fmt.eprintln("Failed to create texture: ", sdl.GetError())
		return
	}
	defer sdl.DestroyTexture(texture)

	// Draw text centered
	dst_rect := sdl.Rect {
		x = x,
		y = y,
		w = text_width,
		h = text_height,
	}
	sdl.RenderCopy(renderer, texture, nil, &dst_rect)
	sdl.RenderPresent(renderer)

}

App_State :: struct {
	window:           ^sdl.Window,
	window_size:      [2]i32,
	renderer:         ^sdl.Renderer,
	ctx:              ui.Context,
	font_atlas:       Font_Atlas,
	font_info:        ^stbtt.fontinfo,
	font_glyph_atlas: Font_Glyph_Atlas,
	running:          bool,
}

deinit_app_state :: proc(app_state: ^App_State) {
	deinit_font_atlas(&app_state.font_atlas)
	sdl.DestroyRenderer(app_state.renderer)
	sdl.DestroyWindow(app_state.window)
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
			sdl.SetRenderDrawColor(
				app_state.renderer,
				val.color.r,
				val.color.g,
				val.color.b,
				val.color.a,
			)
			sdl.RenderDrawRect(app_state.renderer, &rect)
			sdl.RenderFillRect(app_state.renderer, &rect)
		case ui.Command_Text:
			//render_text(
			//	app_state.renderer,
			//	app_state.font_atlas.texture,
			//	val.x,
			//	val.y,
			//	ui.CHAR_WIDTH,
			//	ui.CHAR_HEIGHT,
			//	val.str,
			//)
			render_text_by_font(
				app_state.renderer,
				&app_state.font_glyph_atlas.font_info,
				val.x,
				val.y,
				val.str,
				40,
			)
		}
	}
}

build_simple_text_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.open_element(
		&app_state.ctx,
		"text_container",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 200}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			color = ui.Color{0, 0, 255, 255},
		},
	)
	{
		ui.open_text_element(
			&app_state.ctx,
			"text",
			{
				data = "one two three four five six seven eight nine ten",
				min_width = 100,
				min_height = ui.CHAR_HEIGHT,
			},
		)
		ui.close_element(&app_state.ctx)
	}
	ui.close_element(&app_state.ctx)
	ui.end(&app_state.ctx)
}

build_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.open_element(
		&app_state.ctx,
		"blue",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 1200}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			color = ui.Color{0, 0, 255, 255},
		},
	)
	{
		ui.open_text_element(
			&app_state.ctx,
			"red",
			ui.Text_Element_Config{data = "One Two Three Four"},
		)
		ui.close_element(&app_state.ctx)

		ui.open_element(
			&app_state.ctx,
			"yellow",
			{
				layout = {sizing = {{kind = .Fixed, value = 300}, {kind = .Fixed, value = 300}}},
				color = ui.Color{255, 255, 0, 255},
			},
		)
		ui.close_element(&app_state.ctx)
		ui.open_text_element(
			&app_state.ctx,
			"light blue",
			ui.Text_Element_Config {
				data = "Five Six Seven Eight Nine Ten Eleven Twelve Thirteen Fourteen",
			},
		)
		ui.close_element(&app_state.ctx)
	}
	ui.close_element(&app_state.ctx)
	ui.end(&app_state.ctx)
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
				app_state.running = false
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
			app_state.running = false
		}
	}
}

Font_Atlas :: struct {
	surface: ^sdl.Surface,
	texture: ^sdl.Texture,
}

init_font_atlas :: proc(font_atlas: ^Font_Atlas, renderer: ^sdl.Renderer, path: string) -> bool {
	surface := sdl.LoadBMP(strings.clone_to_cstring(path, context.temp_allocator))
	defer free_all(context.temp_allocator)
	if surface == nil {
		log.error("Failed to load font atlas:", sdl.GetError())
		return false
	}

	// Set color key to make black (0) transparent
	sdl.SetColorKey(surface, 1, 0)

	texture := sdl.CreateTextureFromSurface(renderer, surface)
	if texture == nil {
		log.error("Failed to create texture:", sdl.GetError())
		return false
	}

	font_atlas.surface = surface
	font_atlas.texture = texture

	return true
}

deinit_font_atlas :: proc(font_atlas: ^Font_Atlas) {
	sdl.DestroyTexture(font_atlas.texture)
	sdl.FreeSurface(font_atlas.surface)
}
