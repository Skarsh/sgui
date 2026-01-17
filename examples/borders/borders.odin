
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
		main_sizing := [2]ui.Sizing {
			{kind = .Percentage_Of_Parent, value = 1.0},
			{kind = .Percentage_Of_Parent, value = 1.0},
		}
		main_layout_dir := ui.Layout_Direction.Top_To_Bottom
		main_padding := ui.Padding{50, 50, 50, 50}
		main_child_gap: f32 = 30
		main_bg := base.Fill(base.Color{30, 30, 30, 255})

		if ui.begin_container(
			ctx,
			"main",
			ui.Config_Options {
				layout = {
					sizing = {&main_sizing.x, &main_sizing.y},
					layout_direction = &main_layout_dir,
					padding = &main_padding,
					child_gap = &main_child_gap,
				},
				background_fill = &main_bg,
			},
		) {

			// Test 1: Uniform border, uniform corner radii
			test1_sizing := [2]ui.Sizing {
				{kind = .Fixed, value = 300},
				{kind = .Fixed, value = 100},
			}
			test1_border := ui.Border {
				left   = 5,
				right  = 5,
				top    = 5,
				bottom = 5,
			}
			test1_border_radius := base.Vec4{10, 10, 10, 10}
			test1_border_fill := base.Fill(base.Color{255, 100, 100, 255})
			test1_bg := base.Fill(base.Color{100, 100, 255, 255})
			test1_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test1",
				ui.Config_Options {
					layout = {
						sizing = {&test1_sizing.x, &test1_sizing.y},
						border = &test1_border,
						border_radius = &test1_border_radius,
					},
					background_fill = &test1_bg,
					border_fill = &test1_border_fill,
					capability_flags = &test1_caps,
				},
			)

			// Test 2: Variable border widths, uniform corner radii
			// Using asymmetry to make the shift very obvious
			test2_sizing := [2]ui.Sizing {
				{kind = .Fixed, value = 300},
				{kind = .Fixed, value = 100},
			}

			// Thick right border
			test2_border := ui.Border {
				left   = 5,
				right  = 40,
				top    = 5,
				bottom = 5,
			}
			test2_border_radius := base.Vec4{15, 15, 15, 15}
			test2_border_fill := base.Fill(base.Color{100, 255, 100, 255})
			test2_bg := base.Fill(base.Color{255, 200, 100, 255})
			test2_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test2",
				ui.Config_Options {
					layout = {
						sizing = {&test2_sizing.x, &test2_sizing.y},
						border = &test2_border,
						border_radius = &test2_border_radius,
					},
					background_fill = &test2_bg,
					border_fill = &test2_border_fill,
					capability_flags = &test2_caps,
				},
			)

			// Test 3: Thick left border (should shift content RIGHT)
			test3_sizing := [2]ui.Sizing {
				{kind = .Fixed, value = 300},
				{kind = .Fixed, value = 100},
			}
			test3_border := ui.Border {
				left   = 50,
				right  = 5,
				top    = 5,
				bottom = 5,
			}
			test3_border_radius := base.Vec4{15, 15, 15, 15}
			test3_border_fill := base.Fill(base.Color{255, 255, 100, 255})
			test3_bg := base.Fill(base.Color{100, 255, 255, 255})
			test3_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test3",
				ui.Config_Options {
					layout = {
						sizing = {&test3_sizing.x, &test3_sizing.y},
						border = &test3_border,
						border_radius = &test3_border_radius,
					},
					background_fill = &test3_bg,
					border_fill = &test3_border_fill,
					capability_flags = &test3_caps,
				},
			)

			// Test 4: Variable border widths AND variable corner radii
			test4_sizing := [2]ui.Sizing {
				{kind = .Fixed, value = 300},
				{kind = .Fixed, value = 100},
			}
			test4_border := ui.Border {
				left   = 8,
				right  = 3,
				top    = 10,
				bottom = 15,
			}
			test4_border_radius := base.Vec4{25, 40, 10, 5} // TL, TR, BR, BL
			test4_border_fill := base.Fill(base.Color{255, 100, 255, 255})
			test4_bg := base.Fill(base.Color{200, 200, 200, 255})
			test4_caps := ui.Capability_Flags{.Background}

			ui.container(
				ctx,
				"test4",
				ui.Config_Options {
					layout = {
						sizing = {&test4_sizing.x, &test4_sizing.y},
						border = &test4_border,
						border_radius = &test4_border_radius,
					},
					background_fill = &test4_bg,
					border_fill = &test4_border_fill,
					capability_flags = &test4_caps,
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
