package main

import "core:encoding/hex"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"


import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	r:          f32,
	g:          f32,
	b:          f32,
	a:          f32,
	buf:        []u8,
	buf_len:    int,
	// Small fixed buffers for hex value display (max 2 chars each)
	value_bufs: [4][3]u8,
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
	value_buf: []u8,
) -> ui.Comm {
	comm: ui.Comm

	if ui.begin_container(
		ctx,
		fmt.tprintf("%s_slider_row", id_suffix),
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Left_To_Right,
			alignment_y = .Center,
			child_gap = 10,
		},
	) {
		// TODO(Thomas): @Perf string font size caching
		label_string_width := ui.measure_string_width(ctx, label, ctx.font_id)
		ui.text(
			ctx,
			fmt.tprintf("%s_label", id_suffix),
			label,
			ui.Style {
				sizing_x = ui.sizing_grow(max = label_string_width),
				sizing_y = ui.sizing_fit(),
				text_fill = base.fill(color),
			},
		)

		comm = ui.slider(
			ctx,
			fmt.tprintf("%s_slider", id_suffix),
			value,
			0,
			1,
			.X,
			{},
			ui.Style {
				sizing_x = ui.sizing_fixed(20),
				sizing_y = ui.sizing_fixed(20),
				background_fill = base.fill(color),
				border = ui.border_all(2),
			},
		)

		// Format hex value directly into the provided buffer
		value_str := fmt.bprintf(value_buf, "%x", u8(value^ * 255))
		// TODO(Thomas): @Perf string font size caching
		value_string_width := ui.measure_string_width(ctx, value_str, ctx.font_id)
		ui.text(
			ctx,
			fmt.tprintf("%s_value", id_suffix),
			value_str,
			ui.Style {
				sizing_x = ui.sizing_grow(max = value_string_width),
				sizing_y = ui.sizing_fit(),
				text_alignment_x = .Right,
			},
		)

		ui.end_container(ctx)
	}

	return comm
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// --- Global Style Scope ---
		ui.push_style(
			ctx,
			ui.Style{background_fill = base.fill(WINDOW_BG), text_fill = base.fill(TEXT_COLOR)},
		)
		defer ui.pop_style(ctx)

		// --- Main Panel (centered) ---
		if ui.begin_container(
			ctx,
			"main_panel",
			ui.Style {
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				alignment_x = .Center,
				alignment_y = .Center,
				capability_flags = ui.Capability_Flags{.Background},
			},
		) {
			if ui.begin_container(
				ctx,
				"panel",
				ui.Style {
					alignment_x = .Center,
					alignment_y = .Center,
					layout_direction = .Top_To_Bottom,
					padding = ui.padding_all(15),
					child_gap = 10,
					border_radius = ui.border_radius_all(10),
					background_fill = base.fill(PANEL_BG),
					capability_flags = ui.Capability_Flags{.Background},
				},
			) {

				// --- Color Viewer ---
				color_viewer_size: f32 = 300
				ui.container(
					ctx,
					"color_viewer",
					ui.Style {
						sizing_x = ui.sizing_fixed(color_viewer_size),
						sizing_y = ui.sizing_fixed(color_viewer_size),
						border_radius = ui.border_radius_all(color_viewer_size / 2),
						alignment_x = .Center,
						border = ui.border_all(4),
						background_fill = base.fill_color(
							u8(data.r * 255),
							u8(data.g * 255),
							u8(data.b * 255),
							u8(data.a * 255),
						),
						border_fill = base.fill(
							base.Color {
								u8(data.r * 200),
								u8(data.g * 200),
								u8(data.b * 200),
								u8(data.a * 200),
							},
						),
						capability_flags = ui.Capability_Flags{.Background},
					},
				)

				// --- Sliders ---
				red_comm := make_slider_row(
					ctx,
					"red",
					"R",
					&data.r,
					RED_COLOR,
					data.value_bufs[0][:],
				)
				green_comm := make_slider_row(
					ctx,
					"green",
					"G",
					&data.g,
					GREEN_COLOR,
					data.value_bufs[1][:],
				)
				blue_comm := make_slider_row(
					ctx,
					"blue",
					"B",
					&data.b,
					BLUE_COLOR,
					data.value_bufs[2][:],
				)
				alpha_comm := make_slider_row(
					ctx,
					"alpha",
					"A",
					&data.a,
					ALPHA_COLOR,
					data.value_bufs[3][:],
				)

				// --- Hex Input ---
				hex_comm: ui.Comm
				if ui.begin_container(
					ctx,
					"hex_container",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fit(),
						layout_direction = .Left_To_Right,
						alignment_y = .Center,
						padding = ui.padding_xy(5, 10),
						border_radius = ui.border_radius_all(5),
						child_gap = 10,
						background_fill = base.fill(ITEM_BG),
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
					ui.text(
						ctx,
						"hex_label",
						hex_label_str,
						ui.Style {
							sizing_x = ui.sizing_grow(max = hex_label_string_width),
							sizing_y = ui.sizing_fit(),
						},
					)
					hex_comm = ui.text_input(
						ctx,
						"hex_field",
						data.buf,
						&data.buf_len,
						ui.Style{background_fill = base.fill_color(0, 0, 0, 0)},
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
					if r, r_ok := hex.decode_sequence(hex_from_input[0:2]); r_ok {
						data.r = f32(r) / 255
					}
					if g, g_ok := hex.decode_sequence(hex_from_input[2:4]); g_ok {
						data.g = f32(g) / 255
					}
					if b, b_ok := hex.decode_sequence(hex_from_input[4:6]); b_ok {
						data.b = f32(b) / 255
					}
					if a, a_ok := hex.decode_sequence(hex_from_input[6:8]); a_ok {
						data.a = f32(a) / 255
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
		title       = "Color Picker App",
		window_size = {1280, 720},
		font_path   = "",
		font_id     = 0,
		font_size   = 48,
		memory      = app_memory,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}
	defer app.deinit(my_app)

	buf := make([]u8, 8)
	defer delete(buf)

	my_data := Data {
		r       = 0.5,
		g       = 0.5,
		b       = 0.5,
		a       = 1.0,
		buf     = buf,
		buf_len = 0,
		// value_bufs is zero-initialized automatically as a fixed array in the struct
	}

	app.run(my_app, &my_data, update_and_draw)
}
