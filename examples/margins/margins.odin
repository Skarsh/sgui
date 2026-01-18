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
		main_sizing := [2]ui.Sizing{ui.sizing_percent(1.0), ui.sizing_percent(1.0)}
		main_padding := ui.padding_all(20)
		main_layout_dir := ui.Layout_Direction.Top_To_Bottom
		main_child_gap: f32 = 20

		if ui.begin_container(
			ctx,
			"main",
			ui.Config_Options {
				layout = {
					sizing = {&main_sizing.x, &main_sizing.y},
					padding = &main_padding,
					layout_direction = &main_layout_dir,
					child_gap = &main_child_gap,
				},
			},
		) {

			// Title
			title_sizing := [2]ui.Sizing{ui.sizing_grow(), ui.sizing_grow(max = 50)}
			title_padding := ui.padding_all(10)
			title_bg := base.fill_color(60, 60, 80)

			ui.text(
				ctx,
				"title",
				"Margin Demo - Boxes with different margins",
				ui.Config_Options {
					layout = {
						sizing = {&title_sizing.x, &title_sizing.y},
						text_padding = &title_padding,
					},
					background_fill = &title_bg,
				},
			)

			// Container for boxes
			boxes_sizing := [2]ui.Sizing{ui.sizing_grow(), ui.sizing_fixed(150)}
			boxes_padding := ui.padding_all(20)
			boxes_child_gap: f32 = 0 // No gap, we'll use margins instead
			boxes_bg := base.fill_color(50, 50, 50)
			boxes_layout_dir := ui.Layout_Direction.Left_To_Right

			if ui.begin_container(
				ctx,
				"boxes",
				ui.Config_Options {
					layout = {
						sizing = {&boxes_sizing.x, &boxes_sizing.y},
						padding = &boxes_padding,
						child_gap = &boxes_child_gap,
						layout_direction = &boxes_layout_dir,
					},
					background_fill = &boxes_bg,
				},
			) {
				// Box 1 - Small margin (10px all sides)
				box1_sizing := [2]ui.Sizing{ui.sizing_fixed(100), ui.sizing_grow()}
				box1_margin := ui.margin_all(10)
				box1_bg := base.fill_color(200, 100, 100)

				ui.container(
					ctx,
					"box1",
					ui.Config_Options {
						layout = {
							sizing = {&box1_sizing.x, &box1_sizing.y},
							margin = &box1_margin,
						},
						background_fill = &box1_bg,
					},
				)

				// Box 2 - Medium margin (40px all sides)
				box2_sizing := [2]ui.Sizing{ui.sizing_fixed(100), ui.sizing_grow()}
				box2_margin := ui.margin_all(40)
				box2_bg := base.fill_color(100, 200, 100)

				ui.container(
					ctx,
					"box2",
					ui.Config_Options {
						layout = {
							sizing = {&box2_sizing.x, &box2_sizing.y},
							margin = &box2_margin,
						},
						background_fill = &box2_bg,
					},
				)

				// Box 3 - Asymmetric margin
				box3_sizing := [2]ui.Sizing{ui.sizing_fixed(100), ui.sizing_grow()}
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
					ui.Config_Options {
						layout = {
							sizing = {&box3_sizing.x, &box3_sizing.y},
							margin = &box3_margin,
						},
						background_fill = &box3_bg,
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
