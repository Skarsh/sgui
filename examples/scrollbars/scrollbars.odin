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
	horizontal_scroll_region_str_buf: []u8,
	vertical_scroll_region_str_buf:   []u8,
}

make_info_str :: proc(
	buf: []u8,
	element_id: string,
	size: base.Vec2,
	scroll_region: ui.Scroll_Region,
) -> string {

	scroll_region_info_str := fmt.bprintf(
		buf,
		"%s.size: %.3v\nscroll_offset: %.3v\ntarget_offset: %.3v\nmax_offset: %.3v\ncontent_size: %.3v",
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

	ui.begin(ctx)

	ui.push_style(
		ctx,
		ui.Style {
			capability_flags = ui.Capability_Flags{.Background},
			background_fill = base.fill_color(128, 128, 128),
		},
	)
	defer ui.pop_style(ctx)

	ui.begin_container(
		ctx,
		"main_container",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			padding = ui.padding_all(10),
			child_gap = 10,
			layout_direction = .Left_To_Right,
		},
	)

	ui.begin_container(
		ctx,
		"scroll_box_1",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_grow(),
			padding = ui.padding_all(10),
			layout_direction = .Top_To_Bottom,
		},
	)

	ui.begin_container(
		ctx,
		"horizontal_boxes_wrapper",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_grow(),
			background_fill = base.Color{50, 50, 50, 255},
			padding = ui.padding_all(10),
			child_gap = 5,
			layout_direction = .Left_To_Right,
			capability_flags = ui.Capability_Flags{.Scrollable},
			clip = ui.Clip_Config{{true, true}},
		},
	)

	ui.container(
		ctx,
		"horizontal_box_1",
		ui.Style {
			sizing_x = ui.sizing_percent(0.5),
			sizing_y = ui.sizing_percent(1.0),
			background_fill = base.Color{255, 50, 50, 255},
		},
	)

	ui.container(
		ctx,
		"horizontal_box_2",
		ui.Style {
			sizing_x = ui.sizing_percent(0.5),
			sizing_y = ui.sizing_percent(1.0),
			background_fill = base.Color{50, 255, 50, 255},
		},
	)

	ui.container(
		ctx,
		"horizontal_box_3",
		ui.Style {
			sizing_x = ui.sizing_percent(0.5),
			sizing_y = ui.sizing_percent(1.0),
			background_fill = base.Color{50, 50, 255, 255},
		},
	)

	ui.scrollbar(ctx, "horizontal_scrollbar", "horizontal_boxes_wrapper", .X)

	ui.end_container(ctx)


	// HACK(Thomas): When we have cleaned up the interactive elements issue, the element should
	// hopefully come directly from the creation of the container / widget. So we don't have to
	// find it by id like here.
	horizontal_boxes_wrapper_element, horizontal_boxes_wrapper_element_found :=
		ui.find_element_by_string_id(ctx, "horizontal_boxes_wrapper")
	assert(horizontal_boxes_wrapper_element_found)

	scroll_region := horizontal_boxes_wrapper_element.scroll_region
	scroll_region_info_str := make_info_str(
		data.horizontal_scroll_region_str_buf,
		horizontal_boxes_wrapper_element.id_string,
		horizontal_boxes_wrapper_element.size,
		scroll_region,
	)
	ui.text(ctx, "scroll_box_1_scroll_region_info", scroll_region_info_str)

	ui.end_container(ctx)


	ui.begin_container(
		ctx,
		"scroll_box_2",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_grow(),
			padding = ui.padding_all(10),
			layout_direction = .Top_To_Bottom,
		},
	)

	ui.begin_container(
		ctx,
		"vertical_boxes_wrapper",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_grow(),
			padding = ui.padding_all(10),
			child_gap = 5,
			background_fill = base.Color{50, 50, 50, 255},
			layout_direction = .Top_To_Bottom,
			capability_flags = ui.Capability_Flags{.Scrollable},
			clip = ui.Clip_Config{{true, true}},
		},
	)

	ui.container(
		ctx,
		"vertical_box_1",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(0.5),
			background_fill = base.Color{255, 50, 50, 255},
			margin = ui.margin_trbl(10, 0, 0, 0),
		},
	)

	ui.container(
		ctx,
		"vertical_box_2",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(0.5),
			background_fill = base.Color{50, 255, 50, 255},
		},
	)

	ui.container(
		ctx,
		"vertical_box_3",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(0.5),
			background_fill = base.Color{50, 50, 255, 255},
		},
	)

	ui.scrollbar(ctx, "vertical_scrollbar", "vertical_boxes_wrapper", .Y)

	ui.end_container(ctx)


	// HACK(Thomas): When we have cleaned up the interactive elements issue, the element should
	// hopefully come directly from the creation of the container / widget. So we don't have to
	// find it by id like here.

	vertical_boxes_wrapper_element, vertical_boxes_wrapper_element_found :=
		ui.find_element_by_string_id(ctx, "vertical_boxes_wrapper")
	assert(vertical_boxes_wrapper_element_found)

	vertical_boxes_scroll_region := vertical_boxes_wrapper_element.scroll_region

	vertical_boxes_scroll_region_info_str := make_info_str(
		data.vertical_scroll_region_str_buf,
		vertical_boxes_wrapper_element.id_string,
		vertical_boxes_wrapper_element.size,
		vertical_boxes_scroll_region,
	)

	ui.text(ctx, "scroll_box_2_scroll_region_info", vertical_boxes_scroll_region_info_str)

	ui.end_container(ctx)

	ui.end_container(ctx)

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
		title = "Scrollbars Demo",
		window_size = {1200, 800},
		font_path = "",
		font_id = 0,
		font_size = 24,
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
		log.error("Failed to initialize application")
		return
	}
	defer app.deinit(my_app)

	horizontal_scroll_region_str_buf := [1024]u8{}
	vertical_scroll_region_str_buf := [1024]u8{}

	data := Data{horizontal_scroll_region_str_buf[:], vertical_scroll_region_str_buf[:]}

	app.run(my_app, &data, update_and_draw)
}
