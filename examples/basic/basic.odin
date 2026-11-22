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
	ui.begin_2(ctx)

	ui.push_style(
		ctx,
		ui.Style {
			capability_flags = ui.Capability_Flags{.Background},
			background_fill = base.fill_color(55, 55, 55),
			border = ui.border_all(5),
			border_radius = ui.border_radius_all(5),
			border_fill = base.fill_color(24, 36, 55),
			alignment_x = .Center,
			alignment_y = .Center,
			text_alignment_x = .Center,
			text_alignment_y = .Center,
		},
	)
	defer ui.pop_style(ctx)


	ui.begin_container_2(
		ctx,
		ui.Style{sizing_x = ui.sizing_percent(1.0), sizing_y = ui.sizing_percent(1.0)},
		name = "main_container",
	)

	ui.begin_container_2(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_fixed(200),
			sizing_y = ui.sizing_fixed(70),
			padding = ui.padding_all(10),
			border_fill = base.fill_color(24, 36, 0),
		},
		name = "color_container",
	)

	ui.end_container_2(ctx) //  color container

	ui.end_container_2(ctx) // main container


	ui.end_2(ctx)
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
		app_arena_mem       = make([]u8, 10 * mem.Megabyte, arena_allocator),
		frame_arena_mem     = make([]u8, 100 * mem.Kilobyte, arena_allocator),
		draw_command_buffer = make([]ui.Draw_Command, 1024, arena_allocator),
	}

	config := app.App_Config {
		title = "Basic",
		window_size = {640, 480},
		font_configs = {
			base.Font_Config{"data/fonts/JetBrains_Mono/JetBrainsMono-Regular.ttf", 48, nil},
		},
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			get_clipboard_text = backend.sdl_get_clipboard_text,
			set_clipboard_text = backend.sdl_set_clipboard_text,
			poll_events = backend.sdl_poll_events,
		},
		window_api = backend.create_sdl_window_api(),
		memory = app_memory,
		allocator = context.allocator,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}

	defer app.deinit(my_app)

	my_data := Data{}
	app.run(my_app, &my_data, update_and_draw)
}
