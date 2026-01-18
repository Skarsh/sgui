package main

import "core:log"
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
		ui.push_capability_flags(
			ctx,
			ui.Capability_Flags{.Background},
		); defer ui.pop_capability_flags(ctx)

		ui.push_background_fill(
			ctx,
			base.fill_color(55, 55, 55),
		); defer ui.pop_background_fill(ctx)

		ui.push_border(ctx, ui.border_all(5)); defer ui.pop_border(ctx)
		ui.push_border_radius(ctx, ui.border_radius_all(5)); defer ui.pop_border_radius(ctx)
		ui.push_border_fill(ctx, base.fill_color(24, 36, 55)); defer ui.pop_border_fill(ctx)

		ui.push_alignment_x(ctx, .Center); defer ui.pop_alignment_x(ctx)
		ui.push_alignment_y(ctx, .Center); defer ui.pop_alignment_y(ctx)
		ui.push_text_alignment_x(ctx, .Center); defer ui.pop_text_alignment_x(ctx)
		ui.push_text_alignment_y(ctx, .Center); defer ui.pop_text_alignment_y(ctx)

		main_container_sizing := [2]ui.Sizing{ui.sizing_percent(1.0), ui.sizing_percent(1.0)}

		if ui.begin_container(
			ctx,
			"main_container",
			ui.Config_Options {
				layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}},
			},
		) {

			counter_container_padding := ui.padding_all(10)
			counter_container_child_gap: f32 = 10
			counter_container_sizing := [2]ui.Sizing{ui.sizing_fixed(200), ui.sizing_fixed(70)}

			if ui.begin_container(
				ctx,
				"counter_container",
				ui.Config_Options {
					layout = {
						sizing = {&counter_container_sizing.x, &counter_container_sizing.y},
						padding = &counter_container_padding,
						child_gap = &counter_container_child_gap,
					},
				},
			) {
				ui.push_border_fill(ctx, base.fill_color(24, 36, 0)); defer ui.pop_border_fill(ctx)

				counter_text_border_fill := base.fill_color(0, 0, 0, 0)

				strings.write_int(&data.sb, data.counter)
				num_str := strings.to_string(data.sb)
				defer strings.builder_reset(&data.sb)


				text_background_fill := base.fill_color(0, 0, 0, 0)
				ui.text(
					ctx,
					"counter_text",
					num_str,
					ui.Config_Options {
						border_fill = &counter_text_border_fill,
						background_fill = &text_background_fill,
					},
				)

				ui.push_background_fill(
					ctx,
					base.fill_color(95, 95, 95),
				); defer ui.pop_background_fill(ctx)
				ui.push_border(ctx, ui.border_all(2)); defer ui.pop_border(ctx)

				if ui.button(ctx, "counter_minus_button", "-").clicked {
					data.counter -= 1
				}

				if ui.button(ctx, "counter_plus_button", "+").clicked {
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
