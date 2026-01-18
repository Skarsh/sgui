package main

import "core:log"

import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// Set global background
		ui.push_capability_flags(
			ctx,
			ui.Capability_Flags{.Background},
		); defer ui.pop_capability_flags(ctx)

		ui.push_background_fill(
			ctx,
			base.fill_color(30, 30, 30),
		); defer ui.pop_background_fill(ctx)

		ui.push_alignment_x(ctx, .Center); defer ui.pop_alignment_x(ctx)

		ui.push_alignment_y(ctx, .Center); defer ui.pop_alignment_y(ctx)

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
					text_padding = title_padding,
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

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) {
	build_ui(ctx, data)
}

main :: proc() {
	when ODIN_DEBUG {
		diag := diagnostics.init()
		defer diagnostics.deinit(&diag)
	}

	config := app.App_Config {
		title     = "Margins Demo",
		width     = 800,
		height    = 600,
		font_path = "../../data/fonts/font.ttf",
		font_id   = 0,
		font_size = 24,
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
