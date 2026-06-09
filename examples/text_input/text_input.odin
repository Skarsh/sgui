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
	buf:                   []u8,
	scroll_region_str_buf: []u8,
}

make_info_str :: proc(
	buf: []u8,
	element_id: string,
	size: base.Vec2,
	scroll_region: ui.Scroll_Region,
) -> string {

	scroll_region_info_str := fmt.bprintf(
		buf,
		"%s.size: %.4v\nscroll_offset: %.4v\ntarget_offset: %.4v\nmax_offset: %.4v\ncontent_size: %.4v",
		element_id,
		size,
		scroll_region.offset,
		scroll_region.target_offset,
		scroll_region.max_offset,
		scroll_region.content_size,
	)

	return scroll_region_info_str
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		ui.push_style(
			ctx,
			ui.Style {
				background_fill = base.fill_color(20, 20, 20),
				capability_flags = ui.Capability_Flags{.Background},
			},
		)

		ui.begin_container(
			ctx,
			"main_container",
			ui.Style {
				alignment_x = .Center,
				alignment_y = .Center,
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				padding = ui.padding_all(10),
				child_gap = 10,
				background_fill = base.fill_color(40, 40, 40),
				layout_direction = .Top_To_Bottom,
			},
		)

		text_input_comm := ui.text_input(ctx, "text_input", data.buf)
		text_input_scroll_region := text_input_comm.element.scroll_region

		ui.begin_container(
			ctx,
			"stats_wrapper",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_grow(),
				background_fill = base.fill_color(60, 60, 60),
				alignment_y = .Center,
			},
		)
		ui.text(
			ctx,
			"scroll_stats",
			make_info_str(
				data.scroll_region_str_buf,
				"text_input",
				text_input_comm.element.size,
				text_input_scroll_region,
			),
			ui.Style{background_fill = base.fill_color(60, 60, 60), alignment_x = .Center},
		)

		// stats_wrapper
		ui.end_container(ctx)

		// main_container
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
		title = "Text Input App",
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

	buf := [1024]u8{}
	scroll_region_str_buf := [1024]u8{}
	my_data := Data {
		buf                   = buf[:],
		scroll_region_str_buf = scroll_region_str_buf[:],
	}
	app.run(my_app, &my_data, update_and_draw)
}
