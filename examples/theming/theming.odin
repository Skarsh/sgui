package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	click_count:    int,
	use_dark_theme: bool,
}

// Custom dark theme
dark_theme :: proc() -> ui.Theme {
	theme := ui.default_theme()

	// Override button style - use sizing_fit so buttons fit their content
	theme.button = ui.Style {
		sizing_x         = ui.sizing_fit(),
		sizing_y         = ui.sizing_fit(),
		padding          = ui.padding_all(12),
		text_alignment_x = .Center,
		background_fill  = base.fill_color(30, 30, 35),
		text_fill        = base.fill_color(200, 200, 210),
		border_radius    = ui.border_radius_all(8),
		border           = ui.border_all(1),
		border_fill      = base.fill_color(60, 60, 70),
		capability_flags = ui.Capability_Flags{.Background, .Clickable, .Hot_Animation},
	}

	// Override panel style
	theme.panel = ui.Style {
		padding          = ui.padding_all(20),
		background_fill  = base.fill_color(25, 25, 30),
		border_radius    = ui.border_radius_all(10),
		capability_flags = ui.Capability_Flags{.Background},
	}

	return theme
}

// Custom colorful theme
colorful_theme :: proc() -> ui.Theme {
	theme := ui.default_theme()

	// Override button style with vibrant colors - use sizing_fit so buttons fit their content
	theme.button = ui.Style {
		sizing_x         = ui.sizing_fit(),
		sizing_y         = ui.sizing_fit(),
		padding          = ui.padding_all(12),
		text_alignment_x = .Center,
		background_fill  = base.fill_color(59, 130, 246), // Blue
		text_fill        = base.fill_color(255, 255, 255),
		border_radius    = ui.border_radius_all(8),
		capability_flags = ui.Capability_Flags{.Background, .Clickable, .Hot_Animation},
	}

	// Override panel style
	theme.panel = ui.Style {
		padding          = ui.padding_all(20),
		background_fill  = base.fill_color(45, 45, 55),
		border_radius    = ui.border_radius_all(10),
		capability_flags = ui.Capability_Flags{.Background},
	}

	return theme
}

// Custom button style - Danger
danger_button_style :: proc() -> ui.Style {
	return ui.Style {
		sizing_x         = ui.sizing_fit(),
		sizing_y         = ui.sizing_fit(),
		padding          = ui.padding_all(12),
		text_alignment_x = .Center,
		background_fill  = base.fill_color(220, 38, 38), // Red
		text_fill        = base.fill_color(255, 255, 255),
		border_radius    = ui.border_radius_all(6),
		capability_flags = ui.Capability_Flags{.Background, .Clickable, .Hot_Animation},
	}
}

// Custom button style - Success
success_button_style :: proc() -> ui.Style {
	return ui.Style {
		sizing_x         = ui.sizing_fit(),
		sizing_y         = ui.sizing_fit(),
		padding          = ui.padding_all(12),
		text_alignment_x = .Center,
		background_fill  = base.fill_color(34, 197, 94), // Green
		text_fill        = base.fill_color(255, 255, 255),
		border_radius    = ui.border_radius_all(6),
		capability_flags = ui.Capability_Flags{.Background, .Clickable, .Hot_Animation},
	}
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// Set theme based on toggle
		if data.use_dark_theme {
			ui.set_theme(ctx, dark_theme())
		} else {
			ui.set_theme(ctx, colorful_theme())
		}

		// Push app-wide styles using the style stack
		ui.push_style(
			ctx,
			ui.Style {
				background_fill = base.fill_color(25, 25, 30),
				capability_flags = ui.Capability_Flags{.Background},
			},
		)
		defer ui.pop_style(ctx)

		// Main container
		if ui.begin_container(
			ctx,
			"main",
			ui.Style {
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				padding = ui.padding_all(20),
				layout_direction = .Top_To_Bottom,
				child_gap = 20,
				alignment_x = .Center,
				alignment_y = .Top,
			},
		) {

			// Title
			ui.text(
				ctx,
				"title",
				"Theme Demo",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_grow(max = 40),
					text_fill = base.fill_color(255, 255, 255),
					text_alignment_x = .Center,
					text_alignment_y = .Center,
				},
			)

			// Theme toggle section
			if ui.begin_container(
				ctx,
				"theme_toggle_section",
				ui.Style {
					sizing_x = ui.sizing_fit(),
					sizing_y = ui.sizing_fit(),
					layout_direction = .Left_To_Right,
					child_gap = 10,
					alignment_x = .Center,
					alignment_y = .Center,
				},
			) {
				ui.text(
					ctx,
					"theme_label",
					"Theme:",
					ui.Style {
						sizing_x = ui.sizing_fit(),
						sizing_y = ui.sizing_grow(max = 40),
						text_fill = base.fill_color(200, 200, 200),
						text_alignment_y = .Center,
					},
				)

				// Theme buttons use the current theme's button style
				if ui.button(ctx, "dark_btn", "Dark Theme", ui.get_theme(ctx).button).clicked {
					data.use_dark_theme = true
				}

				if ui.button(ctx, "colorful_btn", "Colorful Theme", ui.get_theme(ctx).button).clicked {
					data.use_dark_theme = false
				}

				ui.end_container(ctx)
			}

			// Custom styles section
			ui.text(
				ctx,
				"custom_label",
				"Custom Button Styles:",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_grow(max = 30),
					text_fill = base.fill_color(180, 180, 180),
					text_alignment_x = .Center,
				},
			)

			if ui.begin_container(
				ctx,
				"custom_buttons",
				ui.Style {
					sizing_x = ui.sizing_fit(),
					sizing_y = ui.sizing_fit(),
					layout_direction = .Left_To_Right,
					child_gap = 10,
					alignment_x = .Center,
				},
			) {
				if ui.button(ctx, "danger_btn", "Danger", danger_button_style()).clicked {
					data.click_count += 1
				}

				if ui.button(ctx, "success_btn", "Success", success_button_style()).clicked {
					data.click_count += 1
				}

				// Default theme button
				if ui.button(ctx, "default_btn", "Default", ui.get_theme(ctx).button).clicked {
					data.click_count += 1
				}

				ui.end_container(ctx)
			}

			// Click counter
			if ui.begin_container(
				ctx,
				"counter_section",
				ui.Style {
					sizing_x = ui.sizing_fit(),
					sizing_y = ui.sizing_fit(),
					layout_direction = .Left_To_Right,
					child_gap = 10,
					alignment_x = .Center,
					alignment_y = .Center,
				},
			) {
				ui.text(
					ctx,
					"click_label",
					"Clicks:",
					ui.Style {
						sizing_x = ui.sizing_fit(),
						sizing_y = ui.sizing_grow(max = 30),
						text_fill = base.fill_color(150, 150, 150),
						text_alignment_y = .Center,
					},
				)

				// Show click count (use frame_allocator so string lives for the frame)
				count_str := fmt.aprintf("%d", data.click_count, allocator = ctx.frame_allocator)
				ui.text(
					ctx,
					"click_count",
					count_str,
					ui.Style {
						sizing_x = ui.sizing_fit(),
						sizing_y = ui.sizing_grow(max = 30),
						text_fill = base.fill_color(255, 255, 255),
						text_alignment_y = .Center,
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
	diag := diagnostics.init()
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
		title = "Theming Demo",
		window_size = {700, 500},
		font_path = "",
		font_id = 0,
		font_size = 20,
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			poll_events = backend.sdl_poll_events,
		},
		memory = app_memory,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}
	defer app.deinit(my_app)

	my_data := Data {
		click_count    = 0,
		use_dark_theme = false,
	}

	app.run(my_app, &my_data, update_and_draw)
}
