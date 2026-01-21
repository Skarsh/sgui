package main

import "core:log"
import "core:mem"

import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	selected_demo: int,
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// Main container
		ui.container(
			ctx,
			"main",
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
			proc(ctx: ^ui.Context, data: ^Data) {
				// Title
				ui.text(
					ctx,
					"title",
					"Flex Layout Demo - Weighted Grow Factors",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						text_fill = base.fill_color(255, 255, 255),
						text_alignment_x = .Center,
					},
				)

				// Demo 1: Equal factors (1:1:1) - traditional equal distribution
				ui.text(
					ctx,
					"demo1_label",
					"1. Equal Factors (1:1:1) - Elements split space equally",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo1",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(60),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						// Three boxes with equal grow factor (1:1:1)
						ui.container(
							ctx,
							"d1_box1",
							ui.Style {
								sizing_x         = ui.sizing_grow(), // factor = 1.0 (default)
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(70, 130, 180),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d1_t1",
									"1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d1_box2",
							ui.Style {
								sizing_x = ui.sizing_grow(),
								sizing_y = ui.sizing_grow(),
								background_fill = base.fill_color(70, 130, 180),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x = .Center,
								alignment_y = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d1_t2",
									"1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d1_box3",
							ui.Style {
								sizing_x = ui.sizing_grow(),
								sizing_y = ui.sizing_grow(),
								background_fill = base.fill_color(70, 130, 180),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x = .Center,
								alignment_y = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d1_t3",
									"1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
					},
				)

				// Demo 2: Weighted factors (1:2:1) - middle gets double
				ui.text(
					ctx,
					"demo2_label",
					"2. Weighted Factors (1:2:1) - Middle element gets 2x space",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo2",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(60),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						ui.container(
							ctx,
							"d2_box1",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(1), // factor = 1
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(180, 100, 100),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d2_t1",
									"1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d2_box2",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(2), // factor = 2 (gets double)
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(180, 100, 100),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d2_t2",
									"2",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d2_box3",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(1), // factor = 1
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(180, 100, 100),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d2_t3",
									"1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
					},
				)

				// Demo 3: Sidebar layout (1:3) - common UI pattern
				ui.text(
					ctx,
					"demo3_label",
					"3. Sidebar Layout (1:3) - Sidebar takes 25%, Content takes 75%",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo3",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(80),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						ui.container(
							ctx,
							"d3_sidebar",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(1), // 1 part
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(60, 60, 70),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d3_t1",
									"Sidebar (1)",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d3_content",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(3), // 3 parts
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(100, 149, 237),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d3_t2",
									"Content (3)",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
					},
				)

				// Demo 4: Zero factor exclusion
				ui.text(
					ctx,
					"demo4_label",
					"4. Zero Factor - Middle element (factor=0) doesn't grow",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo4",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(60),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						ui.container(
							ctx,
							"d4_box1",
							ui.Style {
								sizing_x = ui.sizing_grow_weighted(1),
								sizing_y = ui.sizing_grow(),
								background_fill = base.fill_color(144, 238, 144),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x = .Center,
								alignment_y = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d4_t1",
									"Grows (1)",
									ui.Style{text_fill = base.fill_color(0, 0, 0)},
								)
							},
						)
						ui.container(
							ctx,
							"d4_box2",
							ui.Style {
								sizing_x         = ui.sizing_fixed(80), // Fixed, doesn't participate
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(200, 200, 200),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d4_t2",
									"Fixed",
									ui.Style{text_fill = base.fill_color(0, 0, 0)},
								)
							},
						)
						ui.container(
							ctx,
							"d4_box3",
							ui.Style {
								sizing_x = ui.sizing_grow_weighted(1),
								sizing_y = ui.sizing_grow(),
								background_fill = base.fill_color(144, 238, 144),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x = .Center,
								alignment_y = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d4_t3",
									"Grows (1)",
									ui.Style{text_fill = base.fill_color(0, 0, 0)},
								)
							},
						)
					},
				)

				// Demo 5: Max constraint with weighted grow
				ui.text(
					ctx,
					"demo5_label",
					"5. Max Constraint - Left element capped at 100px, rest goes to right",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo5",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(60),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						ui.container(
							ctx,
							"d5_box1",
							ui.Style {
								sizing_x         = ui.sizing_grow_weighted(1, 0, 100), // max = 100
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(255, 165, 0),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d5_t1",
									"Max 100px",
									ui.Style{text_fill = base.fill_color(0, 0, 0)},
								)
							},
						)
						ui.container(
							ctx,
							"d5_box2",
							ui.Style {
								sizing_x = ui.sizing_grow_weighted(1),
								sizing_y = ui.sizing_grow(),
								background_fill = base.fill_color(255, 200, 100),
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x = .Center,
								alignment_y = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d5_t2",
									"Gets remainder",
									ui.Style{text_fill = base.fill_color(0, 0, 0)},
								)
							},
						)
					},
				)

				// Demo 6: Equal factors with different min constraints reach equal sizes
				ui.text(
					ctx,
					"demo6_label",
					"6. Equal Factors + Min Constraints - Both reach equal size (target-based)",
					ui.Style{text_fill = base.fill_color(200, 200, 200)},
				)
				ui.container(
					ctx,
					"demo6",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fixed(60),
						layout_direction = .Left_To_Right,
						child_gap = 4,
					},
					proc(ctx: ^ui.Context) {
						ui.container(
							ctx,
							"d6_box1",
							ui.Style {
								sizing_x         = ui.sizing_grow(min = 50), // Has min constraint
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(138, 43, 226), // Purple
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d6_t1",
									"min=50, factor=1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
						ui.container(
							ctx,
							"d6_box2",
							ui.Style {
								sizing_x         = ui.sizing_grow(), // No min constraint
								sizing_y         = ui.sizing_grow(),
								background_fill  = base.fill_color(138, 43, 226), // Purple
								capability_flags = ui.Capability_Flags{.Background},
								alignment_x      = .Center,
								alignment_y      = .Center,
							},
							proc(ctx: ^ui.Context) {
								ui.text(
									ctx,
									"d6_t2",
									"min=0, factor=1",
									ui.Style{text_fill = base.fill_color(255, 255, 255)},
								)
							},
						)
					},
				)
			},
		)

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
		title     = "Flex Layout Demo",
		width     = 800,
		height    = 800,
		font_path = "",
		font_id   = 0,
		font_size = 16,
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
