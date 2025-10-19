package main

import "core:fmt"
import "core:log"
import "core:mem"


import "../../app"
import "../../base"
import "../../ui"

Data :: struct {}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		ui.push_capability_flags(
			ctx,
			ui.Capability_Flags{.Background},
		); defer ui.pop_capability_flags(ctx)

		ui.push_background_fill(
			ctx,
			base.Fill(base.Color{55, 55, 55, 255}),
		); defer ui.pop_background_fill(ctx)

		main_container_sizing := [2]ui.Sizing {
			{kind = .Percentage_Of_Parent, value = 1.0},
			{kind = .Percentage_Of_Parent, value = 1.0},
		}
		ui.push_alignment_x(ctx, .Center); defer ui.pop_alignment_x(ctx)
		ui.push_alignment_y(ctx, .Center); defer ui.pop_alignment_y(ctx)

		if ui.begin_container(
			ctx,
			"main_container",
			ui.Config_Options {
				layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}},
			},
		) {

			panel_container_layout_direction := ui.Layout_Direction.Top_To_Bottom

			if ui.begin_container(
				ctx,
				"panel_container",
				ui.Config_Options{layout = {layout_direction = &panel_container_layout_direction}},
			) {

				color_viewer_sizing := [2]ui.Sizing {
					{kind = .Fixed, value = 256},
					{kind = .Fixed, value = 256},
				}
				bg_fill := base.Fill(base.Color{0, 0, 0, 255})
				if ui.begin_container(
					ctx,
					"color_viewer",
					ui.Config_Options {
						layout = {sizing = {&color_viewer_sizing.x, &color_viewer_sizing.y}},
						background_fill = &bg_fill,
					},
				) {
					ui.end_container(ctx)
				}

				red_slider_val: f32 = 0
				green_slider_val: f32 = 0
				blue_slider_val: f32 = 0


				ui.push_background_fill(
					ctx,
					base.Fill(base.Color{95, 95, 95, 255}),
				); defer ui.pop_background_fill(ctx)
				ui.slider(ctx, "red_slider", &red_slider_val, 0, 100)
				ui.slider(ctx, "green_slider", &green_slider_val, 0, 100)
				ui.slider(ctx, "blue_slider", &blue_slider_val, 0, 100)

				ui.end_container(ctx)
			}

			ui.end_container(ctx)
		}

		ui.end(ctx)
	}
}


update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) {
	build_ui(ctx, data)
}

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

	config := app.App_Config {
		title     = "Counter App",
		width     = 640,
		height    = 480,
		font_path = "",
		font_id   = 0,
		font_size = 48,
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
