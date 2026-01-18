
package main

import "core:log"

import "../../app"
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
			test1_sizing_x := ui.sizing_fixed(300)
			test1_sizing_y := ui.sizing_fixed(100)
			test1_border := ui.border_all(5)
			test1_border_radius := ui.border_radius_all(10)
			test1_border_fill := base.fill_color(255, 100, 100)
			test1_bg := base.fill_color(100, 100, 255)
			test1_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test1",
				ui.Style {
					sizing_x = test1_sizing_x,
					sizing_y = test1_sizing_y,
					border = test1_border,
					border_radius = test1_border_radius,
					background_fill = test1_bg,
					border_fill = test1_border_fill,
					capability_flags = test1_caps,
				},
			)

			// Test 2: Variable border widths, uniform corner radii
			// Using asymmetry to make the shift very obvious
			test2_sizing_x := ui.sizing_fixed(300)
			test2_sizing_y := ui.sizing_fixed(100)

			// Thick right border
			test2_border := ui.Border {
				left   = 5,
				right  = 40,
				top    = 5,
				bottom = 5,
			}
			test2_border_radius := ui.border_radius_all(15)
			test2_border_fill := base.fill_color(100, 255, 100)
			test2_bg := base.fill_color(255, 200, 100)
			test2_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test2",
				ui.Style {
					sizing_x = test2_sizing_x,
					sizing_y = test2_sizing_y,
					border = test2_border,
					border_radius = test2_border_radius,
					background_fill = test2_bg,
					border_fill = test2_border_fill,
					capability_flags = test2_caps,
				},
			)

			// Test 3: Thick left border (should shift content RIGHT)
			test3_sizing_x := ui.sizing_fixed(300)
			test3_sizing_y := ui.sizing_fixed(100)
			test3_border := ui.Border {
				left   = 50,
				right  = 5,
				top    = 5,
				bottom = 5,
			}
			test3_border_radius := ui.border_radius_all(15)
			test3_border_fill := base.fill_color(255, 255, 100)
			test3_bg := base.fill_color(100, 255, 255)
			test3_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test3",
				ui.Style {
					sizing_x = test3_sizing_x,
					sizing_y = test3_sizing_y,
					border = test3_border,
					border_radius = test3_border_radius,
					background_fill = test3_bg,
					border_fill = test3_border_fill,
					capability_flags = test3_caps,
				},
			)

			// Test 4: Variable border widths AND variable corner radii
			test4_sizing_x := ui.sizing_fixed(300)
			test4_sizing_y := ui.sizing_fixed(100)
			test4_border := ui.Border {
				left   = 8,
				right  = 3,
				top    = 10,
				bottom = 15,
			}
			test4_border_radius := base.Vec4{25, 40, 10, 5} // TL, TR, BR, BL
			test4_border_fill := base.fill_color(255, 100, 255)
			test4_bg := base.fill_color(200, 200, 200)
			test4_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test4",
				ui.Style {
					sizing_x = test4_sizing_x,
					sizing_y = test4_sizing_y,
					border = test4_border,
					border_radius = test4_border_radius,
					background_fill = test4_bg,
					border_fill = test4_border_fill,
					capability_flags = test4_caps,
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

	config := app.App_Config {
		title     = "Border Test",
		width     = 800,
		height    = 600,
		font_path = "",
		font_id   = 0,
		font_size = 24,
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
