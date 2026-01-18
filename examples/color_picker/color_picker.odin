package main

import "core:encoding/hex"
import "core:fmt"
import "core:log"
import "core:strings"


import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"

// TODO(Thomas): One string builder for each color is wasteful and bad practice. Hacky solution for now.
Data :: struct {
	r:        f32,
	g:        f32,
	b:        f32,
	a:        f32,
	buf:      []u8,
	buf_len:  int,
	red_sb:   strings.Builder,
	green_sb: strings.Builder,
	blue_sb:  strings.Builder,
	alpha_sb: strings.Builder,
}

// --- Style Palette ---
WINDOW_BG :: base.Color{30, 30, 30, 255}
PANEL_BG :: base.Color{45, 45, 45, 255}
ITEM_BG :: base.Color{60, 60, 60, 255}
TEXT_COLOR :: base.Color{220, 220, 220, 255}
BORDER_COLOR :: base.Color{75, 75, 75, 255}

RED_COLOR :: base.Color{217, 74, 74, 255}
GREEN_COLOR :: base.Color{99, 217, 74, 255}
BLUE_COLOR :: base.Color{74, 99, 217, 255}
ALPHA_COLOR :: base.Color{200, 200, 200, 255}
THUMB_BORDER_COLOR :: base.Color{240, 240, 240, 255}


make_slider_row :: proc(
	ctx: ^ui.Context,
	id_suffix, label: string,
	value: ^f32,
	color: base.Color,
	sb: ^strings.Builder,
) -> ui.Comm {

	row_layout_dir := ui.Layout_Direction.Left_To_Right
	row_align_y := ui.Alignment_Y.Center
	row_chlid_gap: f32 = 10
	row_sizing := [2]ui.Sizing{ui.sizing_grow(), ui.sizing_fit()}
	comm: ui.Comm

	if ui.begin_container(
		ctx,
		fmt.tprintf("%s_slider_row", id_suffix),
		ui.Style {
			sizing_x = row_sizing.x,
			sizing_y = row_sizing.y,
			layout_direction = row_layout_dir,
			alignment_y = row_align_y,
			child_gap = row_chlid_gap,
		},
	) {

		// TODO(Thomas): @Perf string font size caching
		label_string_width := ui.measure_string_width(ctx, label, ctx.font_id)
		label_sizing := [2]ui.Sizing{ui.sizing_grow(max = label_string_width), ui.sizing_fit()}
		text_fill := base.fill(color)
		ui.text(
			ctx,
			fmt.tprintf("%s_label", id_suffix),
			label,
			ui.Style{sizing_x = label_sizing.x, sizing_y = label_sizing.y, text_fill = text_fill},
		)

		comm = ui.slider(
			ctx,
			fmt.tprintf("%s_slider", id_suffix),
			value,
			0,
			1,
			.X,
			20,
			base.fill(color),
			ui.border_all(2),
		)

		// TODO(Thomas): This has to be made using a string builder instead
		value_str := fmt.tprintf("%x", u8(value^ * 255))
		strings.write_string(sb, value_str)
		// TODO(Thomas): @Perf string font size caching
		value_string_width := ui.measure_string_width(ctx, value_str, ctx.font_id)
		value_sizing := [2]ui.Sizing{ui.sizing_grow(max = value_string_width), ui.sizing_fit()}
		value_align_x := ui.Alignment_X.Right
		ui.text(
			ctx,
			fmt.tprintf("%s_value", id_suffix),
			strings.to_string(sb^),
			ui.Style {
				sizing_x = value_sizing.x,
				sizing_y = value_sizing.y,
				text_alignment_x = value_align_x,
			},
		)

		ui.end_container(ctx)
	}

	return comm
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// --- Global Style Scope ---
		ui.push_background_fill(ctx, base.fill(WINDOW_BG)); defer ui.pop_background_fill(ctx)
		ui.push_text_fill(ctx, base.fill(TEXT_COLOR)); defer ui.pop_text_fill(ctx)

		// --- Main Panel (centered) ---
		main_panel_sizing := [2]ui.Sizing{ui.sizing_percent(1.0), ui.sizing_percent(1.0)}
		main_panel_align_x := ui.Alignment_X.Center
		main_panel_align_y := ui.Alignment_Y.Center

		if ui.begin_container(
			ctx,
			"main_panel",
			ui.Style {
				sizing_x = main_panel_sizing.x,
				sizing_y = main_panel_sizing.y,
				alignment_x = main_panel_align_x,
				alignment_y = main_panel_align_y,
				capability_flags = ui.Capability_Flags{.Background},
			},
		) {

			panel_align_x := ui.Alignment_X.Center
			panel_align_y := ui.Alignment_Y.Center
			panel_padding := ui.padding_all(15)
			panel_border_radius := ui.border_radius_all(10)
			panel_layout_dir := ui.Layout_Direction.Top_To_Bottom
			panel_child_gap: f32 = 10
			panel_bg := base.fill(PANEL_BG)

			if ui.begin_container(
				ctx,
				"panel",
				ui.Style {
					alignment_x = panel_align_x,
					alignment_y = panel_align_y,
					layout_direction = panel_layout_dir,
					padding = panel_padding,
					child_gap = panel_child_gap,
					border_radius = panel_border_radius,
					background_fill = panel_bg,
					capability_flags = ui.Capability_Flags{.Background},
				},
			) {

				// --- Color Viewer ---
				color_viewer_size: f32 = 300
				color_viewer_sizing := [2]ui.Sizing {
					ui.sizing_fixed(color_viewer_size),
					ui.sizing_fixed(color_viewer_size),
				}

				color_viewer_bg_fill := base.fill_color(
					u8(data.r * 255),
					u8(data.g * 255),
					u8(data.b * 255),
					u8(data.a * 255),
				)

				color_viewer_radius_val := color_viewer_size / 2
				color_viewer_border_radius := ui.border_radius_all(color_viewer_radius_val)
				color_viewer_align_x := ui.Alignment_X.Center
				border := ui.border_all(4)
				border_color := base.Color {
					u8(data.r * 200),
					u8(data.g * 200),
					u8(data.b * 200),
					u8(data.a * 200),
				}
				border_fill := base.fill(border_color)

				ui.container(
					ctx,
					"color_viewer",
					ui.Style {
						sizing_x = color_viewer_sizing.x,
						sizing_y = color_viewer_sizing.y,
						border_radius = color_viewer_border_radius,
						alignment_x = color_viewer_align_x,
						border = border,
						background_fill = color_viewer_bg_fill,
						border_fill = border_fill,
						capability_flags = ui.Capability_Flags{.Background},
					},
				)

				// --- Sliders ---
				strings.builder_reset(&data.red_sb)
				red_comm := make_slider_row(ctx, "red", "R", &data.r, RED_COLOR, &data.red_sb)
				strings.builder_reset(&data.green_sb)
				green_comm := make_slider_row(
					ctx,
					"green",
					"G",
					&data.g,
					GREEN_COLOR,
					&data.green_sb,
				)
				strings.builder_reset(&data.blue_sb)
				blue_comm := make_slider_row(ctx, "blue", "B", &data.b, BLUE_COLOR, &data.blue_sb)
				strings.builder_reset(&data.alpha_sb)
				alpha_comm := make_slider_row(
					ctx,
					"alpha",
					"A",
					&data.a,
					ALPHA_COLOR,
					&data.alpha_sb,
				)

				// --- Hex Input ---
				hex_comm: ui.Comm
				hex_layout_dir := ui.Layout_Direction.Left_To_Right
				hex_align_y := ui.Alignment_Y.Center
				hex_padding := ui.padding_xy(5, 10)
				hex_child_gap: f32 = 10
				hex_border_radius := ui.border_radius_all(5)
				hex_sizing := [2]ui.Sizing{ui.sizing_grow(), ui.sizing_fit()}
				hex_bg := base.fill(ITEM_BG)

				if ui.begin_container(
					ctx,
					"hex_container",
					ui.Style {
						sizing_x = hex_sizing.x,
						sizing_y = hex_sizing.y,
						layout_direction = hex_layout_dir,
						alignment_y = hex_align_y,
						padding = hex_padding,
						border_radius = hex_border_radius,
						child_gap = hex_child_gap,
						background_fill = hex_bg,
						capability_flags = ui.Capability_Flags{.Background},
					},
				) {

					hex_label_str := "#"
					// TODO(Thomas): @Perf string font size caching
					hex_label_string_width := ui.measure_string_width(
						ctx,
						hex_label_str,
						ctx.font_id,
					)
					hex_label_sizing := [2]ui.Sizing {
						ui.sizing_grow(max = hex_label_string_width),
						ui.sizing_fit(),
					}
					ui.text(
						ctx,
						"hex_label",
						hex_label_str,
						ui.Style{sizing_x = hex_label_sizing.x, sizing_y = hex_label_sizing.y},
					)
					input_bg := base.fill_color(0, 0, 0, 0)
					hex_comm = ui.text_input(
						ctx,
						"hex_field",
						data.buf,
						&data.buf_len,
						ui.Style{background_fill = input_bg},
					)

					ui.end_container(ctx)
				}

				// --- Two-Way Data Binding Logic ---
				hex_from_sliders := fmt.tprintf(
					"%02x%02x%02x%02x",
					u8(data.r * 255),
					u8(data.g * 255),
					u8(data.b * 255),
					u8(data.a * 255),
				)
				hex_from_input := hex_comm.text
				is_dragging_slider :=
					red_comm.held || green_comm.held || blue_comm.held || alpha_comm.held

				if is_dragging_slider {
					// Sliders are source of truth, update text field
					n := copy(data.buf, transmute([]u8)hex_from_sliders)
					data.buf_len = n
				} else if hex_from_input != hex_from_sliders && len(hex_from_input) >= 8 {
					// Text field is source of truth, update sliders
					if r_str, ok := strings.substring(hex_from_input, 0, 2); ok {
						if r, r_ok := hex.decode_sequence(r_str); r_ok {
							data.r = f32(r) / 255
						}
					}
					if g_str, ok := strings.substring(hex_from_input, 2, 4); ok {
						if g, g_ok := hex.decode_sequence(g_str); g_ok {
							data.g = f32(g) / 255
						}
					}
					if b_str, ok := strings.substring(hex_from_input, 4, 6); ok {
						if b, b_ok := hex.decode_sequence(b_str); b_ok {
							data.b = f32(b) / 255
						}
					}
					if a_str, ok := strings.substring(hex_from_input, 6, 8); ok {
						if a, a_ok := hex.decode_sequence(a_str); a_ok {
							data.a = f32(a) / 255
						}
					}
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
		title     = "Color Picker App",
		width     = 1280,
		height    = 720,
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

	buf := make([]u8, 8)
	defer delete(buf)

	red_sb_buf := make([]u8, 64)
	defer delete(red_sb_buf)
	red_sb := strings.builder_from_bytes(red_sb_buf)

	green_sb_buf := make([]u8, 64)
	defer delete(green_sb_buf)
	green_sb := strings.builder_from_bytes(green_sb_buf)

	blue_sb_buf := make([]u8, 64)
	defer delete(blue_sb_buf)
	blue_sb := strings.builder_from_bytes(blue_sb_buf)

	alpha_sb_buf := make([]u8, 64)
	defer delete(alpha_sb_buf)
	alpha_sb := strings.builder_from_bytes(alpha_sb_buf)

	my_data := Data {
		r        = 0.5,
		g        = 0.5,
		b        = 0.5,
		a        = 1.0,
		buf      = buf,
		buf_len  = 0,
		red_sb   = red_sb,
		green_sb = green_sb,
		blue_sb  = blue_sb,
		alpha_sb = alpha_sb,
	}

	app.run(my_app, &my_data, update_and_draw)
}
