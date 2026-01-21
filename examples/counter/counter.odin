package main

import "core:log"
import "core:mem"
import "core:strings"

import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	counter: int,
	sb:      strings.Builder,
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
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

		if ui.begin_container(
			ctx,
			"main_container",
			ui.Style{sizing_x = ui.sizing_percent(1.0), sizing_y = ui.sizing_percent(1.0)},
		) {

			if ui.begin_container(
				ctx,
				"counter_container",
				ui.Style {
					sizing_x = ui.sizing_fixed(200),
					sizing_y = ui.sizing_fixed(70),
					padding = ui.padding_all(10),
					child_gap = 10,
					border_fill = base.fill_color(24, 36, 0),
				},
			) {
				strings.write_int(&data.sb, data.counter)
				num_str := strings.to_string(data.sb)
				defer strings.builder_reset(&data.sb)

				ui.text(
					ctx,
					"counter_text",
					num_str,
					ui.Style {
						border_fill = base.fill_color(0, 0, 0, 0),
						background_fill = base.fill_color(0, 0, 0, 0),
					},
				)

				button_style := ui.Style {
					background_fill = base.fill_color(95, 95, 95),
					border          = ui.border_all(2),
				}

				if ui.button(ctx, "counter_minus_button", "-", button_style).clicked {
					data.counter -= 1
				}

				if ui.button(ctx, "counter_plus_button", "+", button_style).clicked {
					data.counter += 1
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
	diag := diagnostics.init()
	context.logger = diag.logger
	context.allocator = mem.tracking_allocator(&diag.tracking_allocator)
	defer diagnostics.deinit(&diag)

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

	string_buffer := [16]u8{}
	my_data := Data {
		counter = 0,
		sb      = strings.builder_from_bytes(string_buffer[:]),
	}
	app.run(my_app, &my_data, update_and_draw)
}
