package main

import "base:intrinsics"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import textpkg "../../text"
import "../../ui"


Data :: struct {
	text_input_buf: []u8,
	status_str_buf: []u8,
	align_x:        base.Alignment_X,
	align_y:        base.Alignment_Y,
	wrap_mode:      textpkg.Text_Wrap_Mode,
}

SAMPLE_TEXT :: "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.\nSphinx of black quartz, judge my vow.\nHow vexingly quick daft zebras jump!"

cycle_enum :: proc(v: $T) -> T where intrinsics.type_is_enum(T) {
	return T((int(v) + 1) % len(T))
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {

		ui.push_style(
			ctx,
			ui.Style {
				background_fill = base.fill_color(40, 40, 40),
				capability_flags = ui.Capability_Flags{.Background},
			},
		)
		defer ui.pop_style(ctx)

		ui.begin_container(
			ctx,
			"main_container",
			ui.Style {
				alignment_x = .Center,
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				padding = ui.padding_all(10),
				child_gap = 40,
				layout_direction = .Top_To_Bottom,
			},
		)

		ui.begin_container(
			ctx,
			"controls",
			ui.Style{child_gap = 10, layout_direction = .Left_To_Right},
		)

		ui.push_style(ctx, ui.Style{background_fill = base.fill_color(80, 80, 80)})
		if ui.button(ctx, "cycle_align_x", "align x").clicked {
			data.align_x = cycle_enum(data.align_x)
		}

		if ui.button(ctx, "cycle_align_y", "align y").clicked {
			data.align_y = cycle_enum(data.align_y)
		}

		if ui.button(ctx, "cycle_wrap_mode", "wrap mode").clicked {
			data.wrap_mode = cycle_enum(data.wrap_mode)
		}
		ui.pop_style(ctx)

		// controls
		ui.end_container(ctx)

		status_str := fmt.bprintf(
			data.status_str_buf,
			"align_x: %v | align_y: %v | wrap: %v",
			data.align_x,
			data.align_y,
			data.wrap_mode,
		)
		ui.text(ctx, "status", status_str)

		// NOTE(Thomas): This isn't affected by text alignment yet.
		ui.text_input(
			ctx,
			"text_input",
			data.text_input_buf,
			ui.Style {
				text_alignment_x = data.align_x,
				text_alignment_y = data.align_y,
				background_fill = base.fill_color(20, 20, 20),
			},
		)

		ui.text(
			ctx,
			"label",
			SAMPLE_TEXT,
			ui.Style {
				sizing_x = ui.sizing_fixed(700),
				sizing_y = ui.sizing_fixed(400),
				text_alignment_x = data.align_x,
				text_alignment_y = data.align_y,
				text_wrap_mode = data.wrap_mode,
				padding = ui.padding_all(20),
				border = ui.border_all(10),
				background_fill = base.fill_color(60, 60, 60),
			},
		)

		// main container
		ui.end_container(ctx)

		ui.end(ctx)
	}
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
		title = "Text Playground App",
		window_size = {1280, 720},
		font_path = "",
		font_id = 0,
		font_size = 48,
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

	text_input_buf := [1024]u8{}
	status_str_buf := [256]u8{}
	my_data := Data {
		text_input_buf = text_input_buf[:],
		status_str_buf = status_str_buf[:],
		align_x        = .Left,
		align_y        = .Top,
		wrap_mode      = .Wrap,
	}
	app.run(my_app, &my_data, update_and_draw)
}
