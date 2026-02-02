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
	if ui.begin(ctx) {
		// Set global background
		ui.push_style(
			ctx,
			ui.Style {
				capability_flags = ui.Capability_Flags{.Background},
				background_fill = base.fill_color(30, 30, 30),
				alignment_x = .Center,
				alignment_y = .Center,
			},
		)
		defer ui.pop_style(ctx)

		// Main container
		main_padding := ui.padding_all(20)

		if ui.begin_container(
			ctx,
			"main",
			ui.Style {
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				padding = main_padding,
				layout_direction = .Top_To_Bottom,
				child_gap = 20,
			},
		) {

			// Title
			title_padding := ui.padding_all(10)
			title_bg := base.fill_color(60, 60, 80)

			ui.text(
				ctx,
				"title",
				"Margin Demo - Boxes with different margins",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_grow(max = 50),
					padding = title_padding,
					background_fill = title_bg,
				},
			)

			// Container for boxes
			boxes_padding := ui.padding_all(20)
			boxes_bg := base.fill_color(50, 50, 50)

			if ui.begin_container(
				ctx,
				"boxes",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(150),
					padding = boxes_padding,
					child_gap = 0,
					layout_direction = .Left_To_Right,
					background_fill = boxes_bg,
				},
			) {
				// Box 1 - Small margin (10px all sides)
				box1_margin := ui.margin_all(10)
				box1_bg := base.fill_color(200, 100, 100)

				ui.container(
					ctx,
					"box1",
					ui.Style {
						sizing_x = ui.sizing_fixed(100),
						sizing_y = ui.sizing_grow(),
						margin = box1_margin,
						background_fill = box1_bg,
					},
				)

				// Box 2 - Medium margin (40px all sides)
				box2_margin := ui.margin_all(40)
				box2_bg := base.fill_color(100, 200, 100)

				ui.container(
					ctx,
					"box2",
					ui.Style {
						sizing_x = ui.sizing_fixed(100),
						sizing_y = ui.sizing_grow(),
						margin = box2_margin,
						background_fill = box2_bg,
					},
				)

				// Box 3 - Asymmetric margin
				box3_margin := ui.Margin {
					top    = 5,
					right  = 20,
					bottom = 30,
					left   = 80,
				}
				box3_bg := base.fill_color(100, 100, 200)

				ui.container(
					ctx,
					"box3",
					ui.Style {
						sizing_x = ui.sizing_fixed(100),
						sizing_y = ui.sizing_grow(),
						margin = box3_margin,
						background_fill = box3_bg,
					},
				)

				ui.end_container(ctx)
			}

			ui.end_container(ctx)
		}

		ui.end(ctx)
	}
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) -> bool {
	if base.is_key_pressed(ctx.input^, base.Key.Escape) {
		return false
	}
	build_ui(ctx, data)
	return true
}

main :: proc() {
	when ODIN_DEBUG {
		diag := diagnostics.init()
		defer diagnostics.deinit(&diag)
	}

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
		title = "Margins Demo",
		window_size = {800, 600},
		font_path = "../../data/fonts/font.ttf",
		font_id = 0,
		font_size = 24,
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
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

	data := Data{}

	app.run(my_app, &data, update_and_draw)
}
