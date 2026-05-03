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
			background_fill = base.fill_color(128, 128, 128),
		},
	)
	defer ui.pop_style(ctx)

	if ui.begin_container(
		ctx,
		"main_container",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			layout_direction = .Top_To_Bottom,
		},
	) {
		if ui.begin_container(
			ctx,
			"boxes_wrapper",
			ui.Style {
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_grow(),
				background_fill = base.Color{50, 50, 50, 255},
				padding = ui.padding_all(10),
				child_gap = 5,
				layout_direction = .Left_To_Right,
				capability_flags = ui.Capability_Flags{.Scrollable},
				clip = ui.Clip_Config{{true, true}},
			},
		) {

			ui.container(
				ctx,
				"box_1",
				ui.Style {
					sizing_x = ui.sizing_percent(0.5),
					sizing_y = ui.sizing_percent(1.0),
					background_fill = base.Color{255, 50, 50, 255},
				},
			)

			ui.container(
				ctx,
				"box_2",
				ui.Style {
					sizing_x = ui.sizing_percent(0.5),
					sizing_y = ui.sizing_percent(1.0),
					background_fill = base.Color{50, 255, 50, 255},
				},
			)

			ui.container(
				ctx,
				"box_3",
				ui.Style {
					sizing_x = ui.sizing_percent(0.5),
					sizing_y = ui.sizing_percent(1.0),
					background_fill = base.Color{50, 50, 255, 255},
				},
			)

			ui.end_container(ctx)
		}

		ui.scrollbar(ctx, "horizontal_scrollbar", "boxes_wrapper", .X)

		ui.end_container(ctx)
	}

	ui.end(ctx)
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) -> bool {
	if base.is_key_pressed(ctx.input^, base.Key.Escape) {
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

	config := app.App_Config {
		title = "Scrollbars Demo",
		window_size = {1200, 800},
		font_path = "",
		font_id = 0,
		font_size = 24,
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
		log.error("Failed to initialize application")
		return
	}
	defer app.deinit(my_app)

	data := Data{}

	app.run(my_app, &data, update_and_draw)
}
