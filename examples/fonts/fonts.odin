package main

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	ui.begin(ctx)
	ui.push_style(
		ctx,
		ui.Style {
			capability_flags = ui.Capability_Flags{.Background},
			background_fill = base.fill_color(55, 55, 55),
		},
	)
	defer ui.pop_style(ctx)

	ui.begin_container(
		ctx,
		ui.Style{sizing_x = ui.sizing_percent(1.0), sizing_y = ui.sizing_percent(1.0)},
		name = "main_container",
	)


	// Make text element using two different font sizes
	// Some different possible approaches:
	// Pass font size argument to ui.text()
	// make font size part of the Style type
	// Add a font stack? so one can push_font and pop_font?

	ui.text(ctx, "This is a font")

	ui.end_container(ctx) // main container

	ui.end(ctx)
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) -> bool {
	if base.is_key_pressed(ctx.interaction.input^, base.Key.Escape) {
		return false
	}
	build_ui(ctx, data)
	return true
}

main :: proc() {
	diag := diagnostics.init()
	context.logger = diag.logger
	context.allocator = mem.tracking_allocator(&diag.tracking_allocator)
	defer diagnostics.deinit(&diag)

	arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&arena, 100 * mem.Megabyte)
	assert(arena_err == .None)
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)

	app_memory := app.App_Memory {
		app_arena_mem      = make([]u8, 10 * mem.Megabyte, arena_allocator),
		frame_arena_mem    = make([]u8, 100 * mem.Kilobyte, arena_allocator),
		draw_cmd_arena_mem = make([]u8, 100 * mem.Kilobyte, arena_allocator),
		io_arena_mem       = make([]u8, 10 * mem.Kilobyte, arena_allocator),
	}

	// CONTINUE HERE: Next step in fonts stuff is to make sure that the text system
	// in the ui package actually uses the right measurement metrics.
	// This is probably why when using the font_id = 1, the text looks clipped,
	// because the text is drawn larger than the box element which still uses
	// metrics for font_id = 0.
	config := app.App_Config {
		title = "Fonts App",
		window_size = {640, 480},
		font_configs = {
			base.Font_Config{"data/fonts/font.ttf", 24},
			base.Font_Config{"data/fonts/font.ttf", 48},
		},
		//font_path = "",
		font_id = 1,
		//font_size = 24,
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			get_clipboard_text = backend.sdl_get_clipboard_text,
			set_clipboard_text = backend.sdl_set_clipboard_text,
			poll_events = backend.sdl_poll_events,
		},
		window_api = backend.create_sdl_window_api(),
		memory = app_memory,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}
	defer app.deinit(my_app)

	string_buffer := [16]u8{}
	my_data := Data{}
	app.run(my_app, &my_data, update_and_draw)
}
