package main

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	selected_demo: int,
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	ui.begin(ctx)
	// Main container
	ui.container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			padding = ui.padding_all(20),
			child_gap = 20,
			layout_direction = .Top_To_Bottom,
			background_fill = base.fill_color(30, 30, 35),
			capability_flags = ui.Capability_Flags{.Background},
		},
		data,
		name = "main",
		body = proc(ctx: ^ui.Context, data: ^Data) {
			// Title
			ui.text(
				ctx,
				"Flex Layout Demo - Weighted Grow Factors",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					text_fill = base.fill_color(255, 255, 255),
					text_alignment_x = .Center,
				},
				name = "title",
			)

			// Demo 1: Equal factors (1:1:1) - traditional equal distribution
			ui.text(
				ctx,
				"1. Equal Factors (1:1:1) - Elements split space equally",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo1_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(60),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo1",
				body = proc(ctx: ^ui.Context) {
					// Three boxes with equal grow factor (1:1:1)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow(), // factor = 1.0 (default)
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(70, 130, 180),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d1_box1",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d1_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x = ui.sizing_grow(),
							sizing_y = ui.sizing_grow(),
							background_fill = base.fill_color(70, 130, 180),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x = .Center,
							alignment_y = .Center,
						},
						name = "d1_box2",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d1_t2",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x = ui.sizing_grow(),
							sizing_y = ui.sizing_grow(),
							background_fill = base.fill_color(70, 130, 180),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x = .Center,
							alignment_y = .Center,
						},
						name = "d1_box3",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d1_t3",
							)
						},
					)
				},
			)

			// Demo 2: Weighted factors (1:2:1) - middle gets double
			ui.text(
				ctx,
				"2. Weighted Factors (1:2:1) - Middle element gets 2x space",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo2_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(60),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo2",
				body = proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(1), // factor = 1
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(180, 100, 100),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d2_box1",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d2_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(2), // factor = 2 (gets double)
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(180, 100, 100),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d2_box2",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"2",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d2_t2",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(1), // factor = 1
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(180, 100, 100),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d2_box3",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d2_t3",
							)
						},
					)
				},
			)

			// Demo 3: Sidebar layout (1:3) - common UI pattern
			ui.text(
				ctx,
				"3. Sidebar Layout (1:3) - Sidebar takes 25%, Content takes 75%",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo3_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(80),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo3",
				body = proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(1), // 1 part
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(60, 60, 70),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d3_sidebar",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Sidebar (1)",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d3_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(3), // 3 parts
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(100, 149, 237),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d3_content",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Content (3)",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d3_t2",
							)
						},
					)
				},
			)

			// Demo 4: Zero factor exclusion
			ui.text(
				ctx,
				"4. Zero Factor - Middle element (factor=0) doesn't grow",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo4_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(60),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo4",
				body = proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						ui.Style {
							sizing_x = ui.sizing_grow_weighted(1),
							sizing_y = ui.sizing_grow(),
							background_fill = base.fill_color(144, 238, 144),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x = .Center,
							alignment_y = .Center,
						},
						name = "d4_box1",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Grows (1)",
								ui.Style{text_fill = base.fill_color(0, 0, 0)},
								name = "d4_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_fixed(80), // Fixed, doesn't participate
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(200, 200, 200),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d4_box2",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Fixed",
								ui.Style{text_fill = base.fill_color(0, 0, 0)},
								name = "d4_t2",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x = ui.sizing_grow_weighted(1),
							sizing_y = ui.sizing_grow(),
							background_fill = base.fill_color(144, 238, 144),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x = .Center,
							alignment_y = .Center,
						},
						name = "d4_box3",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Grows (1)",
								ui.Style{text_fill = base.fill_color(0, 0, 0)},
								name = "d4_t3",
							)
						},
					)
				},
			)

			// Demo 5: Max constraint with weighted grow
			ui.text(
				ctx,
				"5. Max Constraint - Left element capped at 100px, rest goes to right",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo5_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(60),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo5",
				body = proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow_weighted(1, 0, 100), // max = 100
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(255, 165, 0),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d5_box1",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Max 100px",
								ui.Style{text_fill = base.fill_color(0, 0, 0)},
								name = "d5_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x = ui.sizing_grow_weighted(1),
							sizing_y = ui.sizing_grow(),
							background_fill = base.fill_color(255, 200, 100),
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x = .Center,
							alignment_y = .Center,
						},
						name = "d5_box2",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"Gets remainder",
								ui.Style{text_fill = base.fill_color(0, 0, 0)},
								name = "d5_t2",
							)
						},
					)
				},
			)

			// Demo 6: Equal factors with different min constraints reach equal sizes
			ui.text(
				ctx,
				"6. Equal Factors + Min Constraints - Both reach equal size (target-based)",
				ui.Style{text_fill = base.fill_color(200, 200, 200)},
				name = "demo6_label",
			)
			ui.container(
				ctx,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(60),
					layout_direction = .Left_To_Right,
					child_gap = 4,
				},
				name = "demo6",
				body = proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow(min = 50), // Has min constraint
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(138, 43, 226), // Purple
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d6_box1",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"min=50, factor=1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d6_t1",
							)
						},
					)
					ui.container(
						ctx,
						ui.Style {
							sizing_x         = ui.sizing_grow(), // No min constraint
							sizing_y         = ui.sizing_grow(),
							background_fill  = base.fill_color(138, 43, 226), // Purple
							capability_flags = ui.Capability_Flags{.Background},
							alignment_x      = .Center,
							alignment_y      = .Center,
						},
						name = "d6_box2",
						body = proc(ctx: ^ui.Context) {
							ui.text(
								ctx,
								"min=0, factor=1",
								ui.Style{text_fill = base.fill_color(255, 255, 255)},
								name = "d6_t2",
							)
						},
					)
				},
			)
		},
	)

	ui.end(ctx)
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) -> bool {
	if base.is_key_pressed(ctx.interaction.input^, base.Key.Escape) {
		return false
	}
	build_ui(ctx, data)
	return true
}

main :: proc() {
	diag := diagnostics.init()
	context.logger = diag.logger
	context.allocator = mem.tracking_allocator(&diag.tracking_allocator)
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
		title = "Flex Layout Demo",
		window_size = {800, 900},
		font_configs = {
			base.Font_Config{"data/fonts/JetBrains_Mono/JetBrainsMono-Regular.ttf", 24, nil},
		},
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			get_clipboard_text = backend.sdl_get_clipboard_text,
			set_clipboard_text = backend.sdl_set_clipboard_text,
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

	my_data := Data {
		selected_demo = 0,
	}
	app.run(my_app, &my_data, update_and_draw)
}
