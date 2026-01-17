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
		// Set global background
		ui.push_capability_flags(ctx, ui.Capability_Flags{.Background}); defer ui.pop_capability_flags(ctx)

		ui.push_background_fill(ctx, base.Fill(base.Color{30, 30, 30, 255}));defer ui.pop_background_fill(ctx)

		ui.push_alignment_x(ctx, .Center); defer ui.pop_alignment_x(ctx)

		ui.push_alignment_y(ctx, .Center); defer ui.pop_alignment_y(ctx)

		// Main container
		main_sizing := [2]ui.Sizing {
			{kind = .Percentage_Of_Parent, value = 1.0},
			{kind = .Percentage_Of_Parent, value = 1.0},
		}
		main_padding := ui.Padding{top = 20, right = 20, bottom = 20, left = 20}
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
			title_sizing := [2]ui.Sizing{{kind = .Grow}, {kind = .Grow, max_value = 50}}
			title_padding := ui.Padding{top = 10, right = 10, bottom = 10, left = 10}
			title_bg := base.Fill(base.Color{60, 60, 80, 255})

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
			boxes_sizing := [2]ui.Sizing {
				{kind = .Grow},
				{kind = .Fixed, value = 150},
			}
			boxes_padding := ui.Padding{top = 20, right = 20, bottom = 20, left = 20}
			boxes_child_gap: f32 = 0 // No gap, we'll use margins instead
			boxes_bg := base.Fill(base.Color{50, 50, 50, 255})
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
				box1_sizing := [2]ui.Sizing {
					{kind = .Fixed, value = 100},
					{kind = .Grow},
				}
				box1_margin := ui.Margin{top = 10, right = 10, bottom = 10, left = 10}
				box1_bg := base.Fill(base.Color{200, 100, 100, 255})

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
				box2_sizing := [2]ui.Sizing {
					{kind = .Fixed, value = 100},
					{kind = .Grow},
				}
				box2_margin := ui.Margin{top = 40, right = 40, bottom = 40, left = 40}
				box2_bg := base.Fill(base.Color{100, 200, 100, 255})

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
				box3_sizing := [2]ui.Sizing {
					{kind = .Fixed, value = 100},
					{kind = .Grow},
				}
				box3_margin := ui.Margin{top = 5, right = 20, bottom = 30, left = 80}
				box3_bg := base.Fill(base.Color{100, 100, 200, 255})

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
	}

	logger := log.create_console_logger(log.Level.Info)
	context.logger = logger
	defer log.destroy_console_logger(logger)

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
