package main

import "core:encoding/hex"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"


import "../../app"
import "../../base"
import "../../ui"

Data :: struct {
	r:       f32,
	g:       f32,
	b:       f32,
	buf:     []u8,
	buf_len: int,
}

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
			panel_container_child_gap: f32 = 5.0

			if ui.begin_container(
				ctx,
				"panel_container",
				ui.Config_Options {
					layout = {
						layout_direction = &panel_container_layout_direction,
						child_gap = &panel_container_child_gap,
					},
				},
			) {

				color_viewer_width: f32 = 256
				color_viewer_height: f32 = 256
				color_viewer_sizing := [2]ui.Sizing {
					{kind = .Fixed, value = color_viewer_width},
					{kind = .Fixed, value = color_viewer_height},
				}

				color_viewer_bg_fill := base.Fill(
					base.Color{u8(data.r * 255), u8(data.g * 255), u8(data.b * 255), 255},
				)

				color_viewer_radius: f32 = color_viewer_width / 2

				ui.container(
					ctx,
					"color_viewer",
					ui.Config_Options {
						layout = {
							sizing = {&color_viewer_sizing.x, &color_viewer_sizing.y},
							corner_radius = &color_viewer_radius,
						},
						background_fill = &color_viewer_bg_fill,
					},
				)

				ui.push_background_fill(
					ctx,
					base.Fill(base.Color{95, 95, 95, 255}),
				); defer ui.pop_background_fill(ctx)

				ui.slider(ctx, "red_slider", &data.r, 0, 1)
				ui.slider(ctx, "green_slider", &data.g, 0, 1)
				ui.slider(ctx, "blue_slider", &data.b, 0, 1)

				text_comm := ui.text_input(ctx, "hex_field", data.buf, &data.buf_len)

				// TODO(Thomas): This is very dumb, make it better when text input is more complete.
				if len(text_comm.text) >= 6 {
					if r_str, r_str_ok := strings.substring(text_comm.text, 0, 2); r_str_ok {
						r, r_ok := hex.decode_sequence(r_str)
						if r_ok {
							data.r = f32(r) / 255
						}
					}

					if g_str, g_str_ok := strings.substring(text_comm.text, 2, 4); g_str_ok {
						g, g_ok := hex.decode_sequence(g_str)
						if g_ok {
							data.g = f32(g) / 255
						}
					}

					if b_str, b_str_ok := strings.substring(text_comm.text, 4, 6); b_str_ok {
						b, b_ok := hex.decode_sequence(b_str)
						if b_ok {
							data.b = f32(b) / 255
						}
					}
				}

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
		title     = "Color Picker App",
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

	buf := make([]u8, 16)
	defer delete(buf)

	my_data := Data {
		r       = 0.5,
		g       = 0.5,
		b       = 0.5,
		buf     = buf,
		buf_len = 0,
	}

	app.run(my_app, &my_data, update_and_draw)
}
