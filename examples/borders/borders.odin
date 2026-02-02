
package main

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Test_Data :: struct {}

build_ui :: proc(ctx: ^ui.Context, data: ^Test_Data) {
	if ui.begin(ctx) {
		// Main container
		main_sizing_x := ui.sizing_percent(1.0)
		main_sizing_y := ui.sizing_percent(1.0)
		main_layout_dir := ui.Layout_Direction.Top_To_Bottom
		main_padding := ui.padding_all(50)
		main_child_gap: f32 = 30
		main_bg := base.fill_color(30, 30, 30)

		if ui.begin_container(
			ctx,
			"main",
			ui.Style {
				sizing_x = main_sizing_x,
				sizing_y = main_sizing_y,
				layout_direction = main_layout_dir,
				padding = main_padding,
				child_gap = main_child_gap,
				background_fill = main_bg,
			},
		) {

			// Test 1: Uniform border, uniform corner radii
			ui.container(
				ctx,
				"test1",
				ui.Style {
					sizing_x = ui.sizing_fixed(300),
					sizing_y = ui.sizing_fixed(100),
					border = ui.border_all(5),
					border_radius = ui.border_radius_all(10),
					border_fill = base.fill_color(255, 100, 100),
					background_fill = base.fill_color(100, 100, 255),
					capability_flags = ui.Capability_Flags{.Background},
				},
			)

			// Test 2: Variable border widths, uniform corner radii
			// Using asymmetry to make the shift very obvious
			ui.container(
				ctx,
				"test2",
				ui.Style {
					sizing_x = ui.sizing_fixed(300),
					sizing_y = ui.sizing_fixed(100),
					border = ui.Border{5, 40, 5, 5},
					border_radius = ui.border_radius_all(15),
					border_fill = base.fill_color(100, 255, 100),
					background_fill = base.fill_color(255, 200, 100),
					capability_flags = ui.Capability_Flags{.Background},
				},
			)

			// Test 3: Thick Top border (should shift content DOWN)
			ui.container(
				ctx,
				"test3",
				ui.Style {
					sizing_x = ui.sizing_fixed(300),
					sizing_y = ui.sizing_fixed(100),
					border = ui.Border{50, 5, 5, 5},
					border_radius = ui.border_radius_all(15),
					border_fill = base.fill_color(255, 255, 100),
					background_fill = base.fill_color(100, 255, 255),
					capability_flags = ui.Capability_Flags{.Background},
				},
			)

			// Test 4: Variable border widths AND variable corner radii
			ui.container(
				ctx,
				"test4",
				ui.Style {
					sizing_x         = ui.sizing_fixed(300),
					sizing_y         = ui.sizing_fixed(100),
					border           = ui.Border{8, 3, 10, 15},
					border_radius    = base.Vec4{25, 40, 10, 5}, // TL, TR, BR, BL
					border_fill      = base.fill_color(255, 100, 255),
					background_fill  = base.fill_color(200, 200, 200),
					capability_flags = ui.Capability_Flags{.Background},
				},
			)

			ui.end_container(ctx)
		}

		ui.end(ctx)
	}
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
		title = "Border Test",
		window_size = {800, 600},
		font_path = "",
		font_id = 0,
		font_size = 24,
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

	test_data := Test_Data{}
	app.run(my_app, &test_data, build_ui)
}
