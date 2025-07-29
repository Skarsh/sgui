package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import sdl "vendor:sdl2"

import "backend"
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
		sdl.WINDOW_SHOWN | sdl.WINDOW_RESIZABLE,
	)

	if window == nil {
		log.error("Unable to create window: ", sdl.GetError())
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

	font_size: f32 = 48
	font_id: u16 = 0

	ui.init(
		&ctx,
		persistent_arena_allocator,
		frame_arena_allocator,
		{WINDOW_WIDTH, WINDOW_HEIGHT},
		font_id,
		font_size,
	)
	defer ui.deinit(&ctx)

	backend_ctx := backend.Context{}
	backend.init_ctx(&backend_ctx, window, font_size, app_arena_allocator)

	ui.set_text_measurement_callbacks(
		&ctx,
		backend.stb_measure_text,
		backend.stb_measure_glyph,
		&backend_ctx.stb_font_ctx,
	)

	app_state := App_State {
		window      = window,
		window_size = {WINDOW_WIDTH, WINDOW_HEIGHT},
		ctx         = ctx,
		backend_ctx = backend_ctx,
		running     = true,
	}
	defer deinit_app_state(&app_state)

	io := &app_state.backend_ctx.io
	for app_state.running {
		backend.time(io)
		app_state.ctx.dt = io.frame_time.dt
		if io.frame_time.counter % 100 == 0 {
			log.infof("dt: %.2fms", io.frame_time.dt * 1000)
		}

		process_events(&app_state)

		backend.render_begin(&app_state.backend_ctx.render_ctx)

		//build_ui(&app_state)
		//build_ui_2(&app_state)
		//build_simple_text_ui(&app_state)
		//build_nested_text_ui(&app_state)
		//build_grow_ui(&app_state)
		//build_complex_ui(&app_state)
		//build_iterated_texts(&app_state)
		//build_alignment_ui(&app_state)
		build_interactive_button_ui(&app_state)
		//build_text_debugging(&app_state)

		backend.render_end(&app_state.backend_ctx.render_ctx, &app_state.ctx.command_stack)

		sdl.Delay(10)
	}
}

App_State :: struct {
	window:      ^sdl.Window,
	window_size: [2]i32,
	ctx:         ui.Context,
	backend_ctx: backend.Context,
	running:     bool,
}

deinit_app_state :: proc(app_state: ^App_State) {
	backend.deinit(&app_state.backend_ctx)
	sdl.DestroyWindow(app_state.window)
}

build_interactive_button_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"container",
		{
			layout = {
				sizing = {
					{kind = .Percentage_Of_Parent, value = 1.0},
					{kind = .Percentage_Of_Parent, value = 1.0},
				},
				padding = {10, 10, 10, 10},
				child_gap = 10,
			},
			background_color = {48, 200, 128, 255},
			capability_flags = {.Background},
			clip = {{true, true}},
		},
		proc(ctx: ^ui.Context) {
			comm := ui.button(ctx, "button1", "Button 1")
			if comm.active {
				ui.container(
					ctx,
					"panel",
					{
						layout = {
							sizing = {{kind = .Grow}, {kind = .Grow}},
							layout_direction = .Top_To_Bottom,
							padding = {10, 10, 10, 10},
							child_gap = 10,
						},
						background_color = {75, 75, 75, 255},
						capability_flags = {.Background},
					},
					proc(ctx: ^ui.Context) {
						ui.button(ctx, "button2", "Button 2")
						ui.button(ctx, "button3", "Button 3")
						ui.button(ctx, "button4", "Button 4")
					},
				)
			}
		},
	)
	ui.end(&app_state.ctx)
}

build_text_debugging :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"container",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 150}, {kind = .Fit}},
				padding = {10, 10, 10, 10},
				child_gap = 10,
			},
			background_color = {48, 200, 128, 255},
			capability_flags = {.Background},
			clip = {{true, true}},
		},
		proc(ctx: ^ui.Context) {
			ui.text(
				ctx,
				"text1",
				"Button 1",
				text_padding = {10, 10, 10, 10},
				text_alignment_x = .Center,
			)
		},
	)
	ui.end(&app_state.ctx)
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
				"one two three four five six seven eight  nine ten",
				//"one two three four",
				min_width = 100,
				max_width = 100,
				min_height = 30,
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
							ui.text(ctx, "text", "one two three four")
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
			ui.text(ctx, "text1", "One Two\nThree Four\n")

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
				"text2",
				"Five Six Seven\nEight\n\nNine\nTen Eleven Twelve \nThirteen Fourteen",
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

build_iterated_texts :: proc(app_state: ^App_State) {
	item_texts := [5]string{"Copy", "Paste", "Delete", "Comment", "Cut"}
	User_Data :: struct {
		items: [5]string,
	}

	data := User_Data{item_texts}

	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{layout = {sizing = {{kind = .Fit}, {kind = .Fit}}, child_gap = 10}},
		&data,
		proc(ctx: ^ui.Context, data: ^User_Data) {
			for item in data.items {
				ui.text(ctx, item, item)
			}
		},
	)
	ui.end(&app_state.ctx)
}


// TODO(Thomas): This is a quickfix to circumvent the lifetime issue
// of the item_texture_idx passed as rawptr for the image_data
User_Data :: struct {
	items:             [5]string,
	item_texture_idxs: [5]int,
	idx:               int,
	builder:           strings.Builder,
}
item_texts := [5]string{"Copy", "Paste", "Delete", "Comment", "Cut"}
item_texture_idxs := [5]int{1, 2, 3, 4, 5}
user_data := User_Data{}

build_complex_ui :: proc(app_state: ^App_State) {
	buf: [1024]u8
	builder := strings.builder_from_bytes(buf[:])

	user_data.items = item_texts
	user_data.item_texture_idxs = item_texture_idxs
	user_data.builder = builder

	ui.begin(&app_state.ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {
					{kind = .Percentage_Of_Parent, value = 1.0},
					{kind = .Percentage_Of_Parent, value = 1.0},
				},
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

						strings.write_int(&data.builder, data.idx)
						id := strings.to_string(data.builder)
						ui.container(
							ctx,
							id,
							{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
							data,
							proc(ctx: ^ui.Context, data: ^User_Data) {
								item := data.items[data.idx]
								strings.write_int(&data.builder, len(data.items) + data.idx)
								text_id := strings.to_string(data.builder)
								ui.text(
									ctx,
									text_id,
									item,
									text_alignment_x = .Left,
									text_alignment_y = .Center,
								)
							},
						)

						strings.write_int(&data.builder, len(data.items) + data.idx + 13 * 100)
						image_id := strings.to_string(data.builder)
						ui.container(
							ctx,
							image_id,
							{
								layout = {
									sizing = {
										{kind = .Fixed, value = 64},
										{kind = .Fixed, value = 64},
									},
								},
								capability_flags = {.Image},
								content = {image_data = rawptr(&data.item_texture_idxs[data.idx])},
							},
						)
					},
				)
			}
		},
	)
	ui.end(&app_state.ctx)
}

build_alignment_ui :: proc(app_state: ^App_State) {
	ui.begin(&app_state.ctx)

	ui.container(
		&app_state.ctx,
		"parent",
		{
			layout = {
				sizing = {{kind = .Fixed, value = 100}, {kind = .Fixed, value = 100}},
				padding = {10, 10, 10, 10},
			},
			background_color = {255, 125, 172, 255},
			clip = {{true, true}},
			capability_flags = {.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"text_container",
				{layout = {sizing = {{kind = .Grow}, {kind = .Grow}}}},
				proc(ctx: ^ui.Context) {
					ui.text(
						ctx,
						"text",
						"Text",
						text_alignment_x = .Left,
						text_alignment_y = .Center,
					)
				},
			)
		},
	)

	ui.end(&app_state.ctx)
}

// TODO(Thomas): Input handling for ui library shouldn't happen here.
process_events :: proc(app_state: ^App_State) {
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
			key := backend.sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_up(&app_state.ctx, key)
			keymod := backend.sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(&app_state.ctx, keymod)

			#partial switch event.key.keysym.sym {
			case .ESCAPE:
				app_state.running = false
			}
		case .KEYDOWN:
			key := backend.sdl_key_to_ui_key(event.key.keysym.sym)
			ui.handle_key_down(&app_state.ctx, key)
			keymod := backend.sdl_keymod_to_ui_keymod(event.key.keysym.mod)
			ui.handle_keymod_up(&app_state.ctx, keymod)
		case .WINDOWEVENT:
			#partial switch event.window.event {
			case .SIZE_CHANGED:
				app_state.ctx.window_size.x = event.window.data1
				app_state.ctx.window_size.y = event.window.data2
			}
		case .QUIT:
			app_state.running = false
		}
	}
}
