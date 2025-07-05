package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strconv"
import "core:strings"

import sdl "vendor:sdl2"
import sdl_img "vendor:sdl2/image"
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

	ctx := ui.Context{}

	app_arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&app_arena, 10 * mem.Megabyte)
	assert(arena_err == .None)
	app_arena_allocator := virtual.arena_allocator(&app_arena)

	persistent_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&persistent_arena, 100 * mem.Kilobyte)
	assert(arena_err == .None)
	persistent_arena_allocator := virtual.arena_allocator(&persistent_arena)

	frame_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&frame_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	frame_arena_allocator := virtual.arena_allocator(&frame_arena)

	ui.init(&ctx, persistent_arena_allocator, frame_arena_allocator, {WINDOW_WIDTH, WINDOW_HEIGHT})
	defer ui.deinit(&ctx)

	font_size: f32 = 48
	font_id: u16 = 0
	ui.set_ctx_font_id(&ctx, font_id)
	ui.set_ctx_font_size(&ctx, font_size)

	font_info := Font_Info{}
	stb_font_ctx := STB_Font_Context {
		font_info = &font_info,
	}

	if !init_stb_font_ctx(&stb_font_ctx, "data/fonts/font.ttf", font_size) {
		log.error("failed to init stb_font")
		return
	}
	defer deinit_stb_font_ctx(&stb_font_ctx)

	ui.set_text_measurement_callbacks(&ctx, stb_measure_text, stb_measure_glyph, &stb_font_ctx)

	font_atlas := Font_Atlas{}

	init_font_atlas(
		&font_atlas,
		stb_font_ctx.font_info,
		stb_font_ctx.font_data,
		"data/font.ttf",
		font_size,
		1024,
		1024,
		renderer,
		app_arena_allocator,
	)
	defer deinit_font_atlas(&font_atlas)

	render_ctx := Render_Context {
		renderer      = renderer,
		textures      = make([dynamic]Texture_Asset, app_arena_allocator),
		scissor_stack = make([dynamic]sdl.Rect, app_arena_allocator),
	}

	init_resources(&render_ctx)

	app_state := App_State {
		window      = window,
		window_size = {WINDOW_WIDTH, WINDOW_HEIGHT},
		ctx         = ctx,
		render_ctx  = render_ctx,
		font_atlas  = font_atlas,
		running     = true,
	}
	defer deinit_app_state(&app_state)

	now: u32 = 0
	last: u32 = 0
	frame_counter := 0
	for app_state.running {
		frame_counter += 1
		last = now
		now = sdl.GetTicks()
		elapsed := now - last
		if frame_counter % 100 == 0 {
			log.infof("elapsed: {}ms", elapsed)
		}
		process_input(&app_state)

		bg_color := ui.default_color_style[.Window_BG]
		sdl.SetRenderDrawColor(renderer, bg_color.r, bg_color.g, bg_color.b, 255)
		sdl.RenderClear(renderer)

		//build_ui(&app_state)
		//build_ui_2(&app_state)
		//build_simple_text_ui(&app_state)
		//build_nested_text_ui(&app_state)
		//build_grow_ui(&app_state)
		build_complex_ui(&app_state)

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

draw_debug_line :: proc(renderer: ^sdl.Renderer, x0, y0, x1, y1: f32, color: sdl.Color) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderDrawLine(renderer, i32(x0), i32(y0), i32(x1), i32(y1))
}

render_text :: proc(atlas: ^Font_Atlas, text: string, x, y: f32) {
	start_x := x
	start_y := y + atlas.metrics.ascent

	for r in text {
		// TODO(Thomas): What to do with \t and so on?
		if r == '\n' {
			continue
		}

		glyph, found := get_glyph(atlas, r)
		if !found && r != ' ' {
			log.warn("Glyph not found for rune:", r)
		}

		q: stbtt.aligned_quad

		stbtt.GetPackedQuad(
			&atlas.packed_chars[0],
			atlas.atlas_width,
			atlas.atlas_height,
			glyph.pc_idx,
			&start_x,
			&start_y,
			&q,
			true,
		)

		src_rect := sdl.Rect {
			x = i32(q.s0 * f32(atlas.atlas_width)),
			y = i32(q.t0 * f32(atlas.atlas_height)),
			w = i32((q.s1 - q.s0) * f32(atlas.atlas_width)),
			h = i32((q.t1 - q.t0) * f32(atlas.atlas_height)),
		}

		dst_rect := sdl.Rect {
			x = i32(q.x0),
			y = i32(q.y0),
			w = i32(q.x1 - q.x0),
			h = i32(q.y1 - q.y0),
		}

		sdl.RenderCopy(atlas.renderer, atlas.texture, &src_rect, &dst_rect)
	}
}

init_resources :: proc(ctx: ^Render_Context) -> bool {
	logo_surface, logo_ok := load_surface_from_image_file(
		"./data/textures/skarsh_logo_192x192.png",
	)
	if !logo_ok {
		return false
	}

	tex := sdl.CreateTextureFromSurface(ctx.renderer, logo_surface)
	if tex == nil {
		log.error("Failed to crate texture from surface")
		return false
	}

	logo := Texture_Asset {
		tex   = tex,
		w     = logo_surface.w,
		h     = logo_surface.h,
		scale = 1.0,
		pivot = {0.5, 0.5},
	}

	sdl.FreeSurface(logo_surface)

	append(&ctx.textures, logo)

	return true
}

load_surface_from_image_file :: proc(image_path: string) -> (^sdl.Surface, bool) {
	path := strings.clone_to_cstring(image_path, context.temp_allocator)
	surface := sdl_img.Load(path)
	if surface == nil {
		log.errorf("Couldn't load %v", image_path)
		return nil, false
	}

	return surface, true
}

render_image :: proc(ctx: ^Render_Context, x, y, w, h: f32) {
	tex := ctx.textures[0]
	r := sdl.Rect {
		x = i32(x),
		y = i32(y),
		w = i32(w),
		h = i32(w),
	}
	sdl.RenderCopy(ctx.renderer, tex.tex, nil, &r)
}

Texture_Asset :: struct {
	tex:   ^sdl.Texture,
	w:     i32,
	h:     i32,
	scale: f32,
	pivot: struct {
		x: f32,
		y: f32,
	},
}

Render_Context :: struct {
	renderer:      ^sdl.Renderer,
	textures:      [dynamic]Texture_Asset,
	scissor_stack: [dynamic]sdl.Rect,
}

deinit_render_ctx :: proc(ctx: ^Render_Context) {
	sdl.DestroyRenderer(ctx.renderer)
}

App_State :: struct {
	window:      ^sdl.Window,
	window_size: [2]i32,
	ctx:         ui.Context,
	render_ctx:  Render_Context,
	// TODO(Thomas): Figure out how we wanna allocate this.
	font_info:   ^stbtt.fontinfo,
	font_atlas:  Font_Atlas,
	running:     bool,
}

deinit_app_state :: proc(app_state: ^App_State) {
	sdl.DestroyWindow(app_state.window)
}

render_draw_commands :: proc(app_state: ^App_State) {

	render_ctx := &app_state.render_ctx
	clear(&render_ctx.scissor_stack)
	sdl.RenderSetClipRect(render_ctx.renderer, nil)

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
			// NOTE(Thomas): If it's completely transparent,
			// we don't have to draw.
			if val.color.a == 0 {
				continue
			}

			rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}
			sdl.SetRenderDrawColor(
				render_ctx.renderer,
				val.color.r,
				val.color.g,
				val.color.b,
				val.color.a,
			)
			sdl.RenderDrawRect(render_ctx.renderer, &rect)
			sdl.RenderFillRect(render_ctx.renderer, &rect)
		case ui.Command_Text:
			render_text(&app_state.font_atlas, val.str, val.x, val.y)
		case ui.Command_Image:
			render_image(&app_state.render_ctx, val.x, val.y, val.w, val.h)
		case ui.Command_Push_Scissor:
			new_scissor_rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}

			if len(render_ctx.scissor_stack) > 0 {
				parent_rect := render_ctx.scissor_stack[len(render_ctx.scissor_stack) - 1]
				_ = sdl.IntersectRect(&parent_rect, &new_scissor_rect, &new_scissor_rect)
			}

			append(&render_ctx.scissor_stack, new_scissor_rect)
			sdl.RenderSetClipRect(render_ctx.renderer, &new_scissor_rect)

		case ui.Command_Pop_Scissor:
			_ = pop(&render_ctx.scissor_stack)

			if len(render_ctx.scissor_stack) > 0 {
				previous_rect := render_ctx.scissor_stack[len(render_ctx.scissor_stack) - 1]
				sdl.RenderSetClipRect(render_ctx.renderer, &previous_rect)
			} else {
				sdl.RenderSetClipRect(render_ctx.renderer, nil)
			}
		}
	}

	sdl.RenderSetClipRect(render_ctx.renderer, nil)
}

build_simple_text_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"text_container",
		{
			layout = {
				sizing = {{kind = .Fit}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			background_color = ui.Color{0, 0, 255, 255},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.text(
				ctx,
				"text",
				{
					data = "one two three four five six seven eight nine ten",
					min_width = 100,
					max_width = 150,
					min_height = 30,
				},
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_nested_text_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {{kind = .Fit, min_value = 430, max_value = 630}, {kind = .Fit}},
				padding = {16, 16, 16, 16},
				layout_direction = .Top_To_Bottom,
				alignment_x = .Center,
				child_gap = 16,
			},
			background_color = {102, 51, 153, 255},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"grow",
				{
					layout = {
						sizing = {{kind = .Grow}, {kind = .Fit, min_value = 80}},
						padding = {32, 32, 16, 16},
						child_gap = 32,
						alignment_x = .Left,
						alignment_y = .Center,
					},
					background_color = {255, 0, 0, 255},
					capability_flags = {.Background},
					clip = {{true, false}},
				},
				proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						"fit",
						{
							layout = {sizing = {{kind = .Fit}, {kind = .Fit}}},
							background_color = {157, 125, 172, 255},
							capability_flags = {.Background},
						},
						proc(ctx: ^ui.Context) {
							ui.text(ctx, "text", {data = "one two three four"})
						},
					)
				},
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"blue",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 1200}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
				layout_direction = .Left_To_Right,
			},
			background_color = ui.Color{0, 0, 255, 255},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.text(ctx, "red", {data = "One Two\nThree Four\n"})

			ui.container(
				ctx,
				"yellow",
				{
					layout = {sizing = {{kind = .Grow}, {kind = .Fixed, value = 300}}},
					background_color = ui.Color{255, 255, 0, 255},
					capability_flags = {.Background},
				},
			)
			ui.text(
				ctx,
				"light_blue",
				{data = "Five Six Seven\nEight\n\nNine\nTen Eleven Twelve \nThirteen Fourteen"},
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_ui_2 :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {{kind = .Fit, min_value = 100, max_value = 200}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
			},
			background_color = ui.Color{255, 255, 255, 255},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"child_1",
				{
					layout = {
						sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}},
					},
					background_color = ui.Color{255, 0, 0, 255},
					capability_flags = {.Background},
				},
			)
			ui.container(
				ctx,
				"child_2",
				{
					layout = {
						sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}},
					},
					background_color = ui.Color{0, 255, 0, 255},
					capability_flags = {.Background},
				},
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_grow_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 400}, {kind = .Fit}},
				padding = ui.Padding{left = 10, top = 10, right = 10, bottom = 10},
				child_gap = 10,
			},
			background_color = ui.Color{255, 255, 255, 255},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"child_1",
				{
					layout = {sizing = {{kind = .Grow}, {kind = .Fixed, value = 100}}},
					background_color = ui.Color{255, 0, 0, 255},
					capability_flags = {.Background},
				},
			)

			ui.container(
				ctx,
				"child_2",
				{
					layout = {
						sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}},
					},
					background_color = ui.Color{0, 255, 0, 255},
					capability_flags = {.Background},
				},
			)

			ui.container(
				ctx,
				"child_3",
				{
					layout = {sizing = {{kind = .Grow, max_value = 50}, {kind = .Grow}}},
					background_color = ui.Color{0, 0, 255, 255},
					capability_flags = {.Background},
				},
			)

		},
	)
	ui.end(&app_state.ctx)
}

build_complex_ui :: proc(app_state: ^App_State) {

	item_texts := [5]string{"Copy", "Paste", "Delete", "Comment", "Cut"}

	buf: [32]u8

	User_Data :: struct {
		items: [5]string,
		buf:   [32]u8,
		idx:   int,
	}

	user_data := User_Data{item_texts, buf, 0}

	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {{kind = .Fit, min_value = 430, max_value = 630}, {kind = .Fit}},
				padding = {16, 16, 16, 16},
				layout_direction = .Top_To_Bottom,
				alignment_x = .Center,
				child_gap = 16,
			},
			background_color = {102, 51, 153, 255},
			capability_flags = {.Background},
		},
		&user_data,
		proc(ctx: ^ui.Context, data: ^User_Data) {
			for item, idx in data.items {
				data.idx = idx
				ui.container(
					ctx,
					item,
					{
						layout = {
							sizing = {{kind = .Grow}, {kind = .Fit, min_value = 80}},
							padding = {32, 32, 16, 16},
							child_gap = 32,
							alignment_x = .Left,
							alignment_y = .Center,
						},
						background_color = {255, 125, 172, 255},
						clip = {{true, true}},
						capability_flags = {.Background},
					},
					data,
					proc(ctx: ^ui.Context, data: ^User_Data) {

						ui.container(
							ctx,
							strconv.itoa(data.buf[:], data.idx),
							{layout = {sizing = {{kind = .Grow}, {}}}},
							data,
							proc(ctx: ^ui.Context, data: ^User_Data) {

								item := data.items[data.idx]
								ui.text(
									ctx,
									strconv.itoa(data.buf[:], len(data.items) + data.idx),
									{data = item, alignment_x = .Left, alignment_y = .Center},
								)
							},
						)

						ui.container(
							ctx,
							strconv.itoa(data.buf[:], len(data.items) + data.idx + 13 * 100),
							{
								layout = {
									sizing = {
										{kind = .Fixed, value = 64},
										{kind = .Fixed, value = 64},
									},
								},
								capability_flags = {.Image},
							},
						)
					},
				)
			}
		},
	)
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
