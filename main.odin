package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import sdl "vendor:sdl2"

import "backend"
import "base"
import "diagnostics"
import "ui"

// This example uses SDL2, but the immediate mode ui library should be
// rendering and windowing agnostic

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

main :: proc() {
	diag := diagnostics.init()
	defer diagnostics.deinit(&diag)

	window, window_ok := backend.init_and_create_window("ImGUI", WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(window_ok)
	defer backend.deinit_window(window)

	ctx := ui.Context{}


	// TODO(Thomas): This is annoying for the user to have to make, what if a compromise
	// could be to take in three pre-allocated blocks of memory for this instead?
	// so ui.init would take two blocks, one for persistent and one for the frame arena
	// and the backend would take the app_arena and io_arena?
	app_arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&app_arena, 10 * mem.Megabyte)
	assert(arena_err == .None)
	app_arena_allocator := virtual.arena_allocator(&app_arena)

	persistent_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&persistent_arena, 100 * mem.Kilobyte)
	assert(arena_err == .None)
	persistent_arena_allocator := virtual.arena_allocator(&persistent_arena)

	frame_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&frame_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	frame_arena_allocator := virtual.arena_allocator(&frame_arena)

	draw_cmd_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&draw_cmd_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	draw_cmd_arena_allocator := virtual.arena_allocator(&draw_cmd_arena)

	io_arena := virtual.Arena{}
	arena_err = virtual.arena_init_static(&io_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	io_arena_allocator := virtual.arena_allocator(&io_arena)

	font_size: f32 = 48
	font_id: u16 = 0

	ui.init(
		&ctx,
		persistent_arena_allocator,
		frame_arena_allocator,
		draw_cmd_arena_allocator,
		{WINDOW_WIDTH, WINDOW_HEIGHT},
		font_id,
		font_size,
	)
	defer ui.deinit(&ctx)

	backend_ctx := backend.Context{}
	backend.init_ctx(
		&backend_ctx,
		&ctx,
		window,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		font_size,
		app_arena_allocator,
		io_arena_allocator,
	)

	app_state := App_State {
		window      = window,
		window_size = {WINDOW_WIDTH, WINDOW_HEIGHT},
		ctx         = ctx,
		backend_ctx = backend_ctx,
		running     = true,
	}
	defer deinit_app_state(&app_state)

	// TODO(Thomas): All this texture related and complex_ui_data stuff is
	// really app / example specific, and should be moved when we get to the point
	// where we start making standalone examples.
	tex_1, tex_1_ok := backend.opengl_create_texture_from_file("data/textures/copy_icon.png")
	assert(tex_1_ok)
	defer backend.opengl_delete_texture(&tex_1.id)

	tex_2, tex_2_ok := backend.opengl_create_texture_from_file("data/textures/paste_icon.png")
	assert(tex_2_ok)
	defer backend.opengl_delete_texture(&tex_2.id)

	tex_3, tex_3_ok := backend.opengl_create_texture_from_file("data/textures/delete_icon.png")
	assert(tex_3_ok)
	defer backend.opengl_delete_texture(&tex_3.id)

	tex_4, tex_4_ok := backend.opengl_create_texture_from_file("data/textures/comment_icon.png")
	assert(tex_4_ok)
	defer backend.opengl_delete_texture(&tex_4.id)

	tex_5, tex_5_ok := backend.opengl_create_texture_from_file("data/textures/cut_icon.png")
	assert(tex_5_ok)
	defer backend.opengl_delete_texture(&tex_5.id)

	image_data := Image_Data {
		i32(tex_1.id),
		i32(tex_2.id),
		i32(tex_3.id),
		i32(tex_4.id),
		i32(tex_5.id),
	}

	// Data for the complex ui case
	item_texts := [5]string{"Copy", "Paste", "Delete", "Comment", "Cut"}
	item_texture_idxs := [5]int {
		int(image_data.tex_1),
		int(image_data.tex_2),
		int(image_data.tex_3),
		int(image_data.tex_4),
		int(image_data.tex_5),
	}
	complex_ui_data := Complex_UI_Data{}
	complex_ui_data.items = item_texts
	complex_ui_data.item_texture_idxs = item_texture_idxs

	io := &app_state.backend_ctx.io
	for app_state.running {
		backend.time(io)
		app_state.ctx.dt = io.frame_time.dt
		if io.frame_time.counter % 100 == 0 {
			log.infof("dt: %.2fms", io.frame_time.dt * 1000)
		}

		process_events(&app_state)
		backend.process_events(&app_state.backend_ctx, &app_state.ctx)

		backend.render_begin(&app_state.backend_ctx.render_ctx)

		//build_simple_text_ui(&app_state)
		//build_nested_text_ui(&app_state)
		//build_complex_ui(&app_state, &complex_ui_data)
		//build_interactive_button_ui(&app_state)
		//build_styled_ui(&app_state)
		//build_percentage_of_parent_ui(&app_state)
		//build_grow_ui(&app_state)
		//build_multiple_images_ui(&app_state, &image_data)
		//build_relative_layout_ui(&app_state)
		build_bug_repro(&app_state)

		backend.render_end(&app_state.backend_ctx.render_ctx, app_state.ctx.command_queue[:])

		// TODO(Thomas): Shouldn't use sdl.Delay directly here. Should use our own variant.
		sdl.Delay(10)
	}
}

// TODO(Thomas): Should this App_State be something that the library can give when initalized?
// The only app specific thing here is the running boolean, all the rest is something every application
// that uses this library would need to set up. This is really part of the API design for the library.
App_State :: struct {
	window:      backend.Window,
	window_size: [2]i32,
	ctx:         ui.Context,
	backend_ctx: backend.Context,
	running:     bool,
}

deinit_app_state :: proc(app_state: ^App_State) {
	backend.deinit(&app_state.backend_ctx)
}

Image_Data :: struct {
	tex_1: i32,
	tex_2: i32,
	tex_3: i32,
	tex_4: i32,
	tex_5: i32,
}

texts := []string{"yes", "nonnnnnnnnnnnnnnnnnnnnnn", "maybe"}
build_bug_repro :: proc(app_state: ^App_State) {

	build_rows :: proc(ctx: ^ui.Context, texts: []string) {
		b := false
		row_child_gap: f32 = 5
		bg_fill: base.Fill
		for text, i in texts {
			if i % 3 == 0 {
				bg_fill = base.fill_color(255, 0, 0)
			} else if i % 3 == 1 {
				bg_fill = base.fill_color(0, 255, 0)
			} else if i % 3 == 2 {
				bg_fill = base.fill_color(0, 0, 255)
			}

			if ui.begin_container(
				ctx,
				fmt.tprintf("row_%d", i),
				ui.Style {
					padding = ui.padding_all(10),
					child_gap = row_child_gap,
					background_fill = bg_fill,
				},
			) {

				ui.checkbox(ctx, fmt.tprintf("checkbox_%d", i), &b, {})
				ui.spacer(ctx)
				ui.text(ctx, fmt.tprintf("text_%d", i), text)
				ui.spacer(ctx)
				ui.button(ctx, fmt.tprintf("button_%d", i), "Delete")

				ui.end_container(ctx)
			}
		}
	}

	ctx := &app_state.ctx
	if ui.begin(ctx) {

		ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
		ui.push_background_fill(
			ctx,
			base.fill_color(50, 50, 50),
		); defer ui.pop_background_fill(ctx)

		if ui.begin_container(
			ctx,
			"main_container",
			ui.Style {
				sizing_x = ui.sizing_percent(0.5),
				sizing_y = ui.sizing_percent(0.5),
				alignment_x = .Center,
				alignment_y = .Center,
			},
		) {

			if ui.begin_container(
				ctx,
				"panel_container",
				ui.Style{layout_direction = .Top_To_Bottom},
			) {

				build_rows(ctx, texts)

				ui.end_container(ctx)
			}

			ui.end_container(ctx)
		}


		ui.end(ctx)
	}
}

build_relative_layout_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
	ui.push_background_fill(ctx, base.fill_color(128, 128, 128)); defer ui.pop_background_fill(ctx)

	if ui.begin_container(
		ctx,
		"main_container",
		ui.Style {
			sizing_x = ui.sizing_fixed(400),
			sizing_y = ui.sizing_fixed(400),
			layout_mode = .Relative,
		},
	) {

		ui.push_background_fill(ctx, base.fill_color(255, 0, 0)); defer ui.pop_background_fill(ctx)

		ui.container(
			ctx,
			"child",
			ui.Style {
				sizing_x = ui.sizing_fixed(50),
				sizing_y = ui.sizing_fixed(50),
				alignment_x = .Right,
				alignment_y = .Bottom,
				relative_position = base.Vec2{-10, -10},
			},
		)
		ui.end_container(ctx)
	}

	ui.end(ctx)
}

build_multiple_images_ui :: proc(app_state: ^App_State, image_data: ^Image_Data) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_background_fill(ctx, base.fill_color(255, 255, 255)); defer ui.pop_background_fill(ctx)

	ui.container(
		ctx,
		"main_container",
		ui.Style{sizing_x = ui.sizing_grow(), sizing_y = ui.sizing_grow()},
		image_data,
		proc(ctx: ^ui.Context, data: ^Image_Data) {

			ui.push_sizing_x(ctx, ui.sizing_fixed(256)); defer ui.pop_sizing_x(ctx)
			ui.push_sizing_y(ctx, ui.sizing_fixed(256)); defer ui.pop_sizing_y(ctx)

			ui.push_capability_flags(
				ctx,
				ui.Capability_Flags{.Image},
			); defer ui.pop_capability_flags(ctx)


			// Images use content, not style - set image_data after element creation
			if elem_1, ok := ui.open_element(ctx, "image_1"); ok {
				elem_1.config.content.image_data = rawptr(&data.tex_1)
				ui.close_element(ctx)
			}

			if elem_2, ok := ui.open_element(ctx, "image_2"); ok {
				elem_2.config.content.image_data = rawptr(&data.tex_2)
				ui.close_element(ctx)
			}

			if elem_3, ok := ui.open_element(ctx, "image_3"); ok {
				elem_3.config.content.image_data = rawptr(&data.tex_3)
				ui.close_element(ctx)
			}

			if elem_4, ok := ui.open_element(ctx, "image_4"); ok {
				elem_4.config.content.image_data = rawptr(&data.tex_4)
				ui.close_element(ctx)
			}

			if elem_5, ok := ui.open_element(ctx, "image_5"); ok {
				elem_5.config.content.image_data = rawptr(&data.tex_5)
				ui.close_element(ctx)
			}
		},
	)

	ui.end(ctx)
}

build_percentage_of_parent_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_capability_flags(
		ctx,
		ui.Capability_Flags{.Background},
	); defer ui.pop_capability_flags(ctx)

	ui.push_background_fill(ctx, base.fill_color(255, 0, 0)); defer ui.pop_background_fill(ctx)

	// Child 1
	ui.container(
		ctx,
		"child_1",
		ui.Style{sizing_x = ui.sizing_percent(0.5), sizing_y = ui.sizing_percent(0.5)},
	)

	ui.push_background_fill(ctx, base.fill_color(0, 0, 255)); defer ui.pop_background_fill(ctx)

	// Child 2
	ui.container(
		ctx,
		"child_2",
		ui.Style{sizing_x = ui.sizing_percent(0.5), sizing_y = ui.sizing_percent(0.5)},
	)

	ui.end(ctx)
}

build_grow_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_capability_flags(
		ctx,
		ui.Capability_Flags{.Background},
	); defer ui.pop_capability_flags(ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		ui.Style {
			sizing_x = ui.sizing_fixed(400),
			sizing_y = ui.sizing_fit(),
			padding = ui.padding_all(10),
			child_gap = 10,
			background_fill = base.fill_color(255, 255, 255),
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"child_1",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(100),
					background_fill = base.fill_color(255, 0, 0),
				},
			)

			ui.container(
				ctx,
				"child_2",
				ui.Style {
					sizing_x = ui.sizing_fixed(100),
					sizing_y = ui.sizing_fixed(100),
					background_fill = base.fill_color(0, 255, 0),
				},
			)

			ui.container(
				ctx,
				"child_3",
				ui.Style {
					sizing_x = ui.sizing_grow(max = 50),
					sizing_y = ui.sizing_grow(),
					background_fill = base.fill_color(0, 0, 255),
				},
			)

		},
	)
	ui.end(ctx)
}

build_styled_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_background_fill(ctx, base.fill_color(25, 25, 30)); defer ui.pop_background_fill(ctx)
	ui.push_padding(ctx, ui.padding_all(20)); defer ui.pop_padding(ctx)
	ui.push_layout_direction(ctx, .Top_To_Bottom); defer ui.pop_layout_direction(ctx)
	ui.push_child_gap(ctx, 15); defer ui.pop_child_gap(ctx)

	ui.push_sizing_x(ctx, {kind = .Grow}); defer ui.pop_sizing_x(ctx)
	ui.push_sizing_y(ctx, {kind = .Fit}); defer ui.pop_sizing_y(ctx)

	ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
	ui.push_border_radius(ctx, ui.border_radius_all(10)); defer ui.pop_border_radius(ctx)

	ui.push_border_fill(
		ctx,
		base.fill_gradient({2, 0, 36, 255}, {9, 121, 105, 255}, {1, 0}),
	); defer ui.pop_border_fill(ctx)

	ui.container(
		ctx,
		"main_container",
		ui.Style{sizing_x = ui.sizing_percent(1.0), sizing_y = ui.sizing_percent(1.0)},
		proc(ctx: ^ui.Context) {

			ui.text(
				ctx,
				"title",
				"Themed UI Demo",
				ui.Style {
					text_padding = ui.padding_all(5),
					text_fill = base.fill_color(230, 230, 230),
				},
			)

			{
				ui.push_background_fill(
					ctx,
					base.fill_color(80, 50, 60),
				); defer ui.pop_background_fill(ctx)
				ui.push_padding(ctx, ui.padding_all(10)); defer ui.pop_padding(ctx)
				ui.push_layout_direction(ctx, .Left_To_Right); defer ui.pop_layout_direction(ctx)

				ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
				ui.push_border_radius(
					ctx,
					ui.border_radius_all(10),
				); defer ui.pop_border_radius(ctx)
				ui.push_clip_config(ctx, {{true, true}}); defer ui.pop_clip_config(ctx)

				//ui.push_border_thickness(ctx, 2); defer ui.pop_border_thickness(ctx)
				ui.container(ctx, "button_panel", proc(ctx: ^ui.Context) {

					ui.push_background_fill(
						ctx,
						base.fill_gradient({0, 0, 0, 255}, {255, 255, 255, 255}, {1, 0}),
					); defer ui.pop_background_fill(ctx)
					ui.button(ctx, "button1", "Button A")

					ui.push_background_fill(
						ctx,
						base.fill_gradient({81, 163, 163, 255}, {117, 72, 94, 210}, {1, 0}),
					); defer ui.pop_background_fill(ctx)
					ui.button(ctx, "button2", "Button B")

					ui.push_background_fill(
						ctx,
						base.fill_color(150, 50, 50),
					); defer ui.pop_background_fill(ctx)

					ui.push_background_fill(
						ctx,
						base.fill_color(255, 144, 101),
					); defer ui.pop_background_fill(ctx)
					ui.button(
						ctx,
						"button3",
						"Danger Button",
						ui.Style{text_fill = base.fill_color(255, 255, 255)},
					)
					ui.pop_background_fill(ctx)
				})
			}

			ui.text(
				ctx,
				"footer_text",
				"The styles above were scoped.",
				ui.Style {
					text_padding = ui.padding_all(5),
					text_fill = base.fill_color(255, 150, 150),
				},
			)
		},
	)

	ui.end(ctx)
}

build_interactive_button_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_padding(ctx, ui.padding_all(10)); defer ui.pop_padding(ctx)
	ui.push_child_gap(ctx, 10); defer ui.pop_child_gap(ctx)
	ui.push_capability_flags(ctx, ui.Capability_Flags{.Background})

	ui.container(
		&app_state.ctx,
		"container",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			background_fill = base.fill_color(48, 200, 128),
			clip = ui.Clip_Config{{true, true}},
		},
		proc(ctx: ^ui.Context) {
			comm := ui.button(ctx, "button1", "Button 1")
			if comm.active {
				ui.container(
					ctx,
					"panel",
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_grow(),
						layout_direction = .Top_To_Bottom,
						background_fill = base.fill_color(75, 75, 75),
					},
					proc(ctx: ^ui.Context) {
						ui.button(ctx, "button2", "Button 2")
						ui.button(ctx, "button3", "Button 3")
						ui.button(ctx, "button4", "Button 4")
					},
				)
			}
		},
	)
	ui.end(&app_state.ctx)
}

build_simple_text_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx

	ui.begin(ctx)

	ui.container(
		ctx,
		"text_container",
		ui.Style {
			sizing_x = ui.sizing_fit(),
			sizing_y = ui.sizing_fit(),
			padding = ui.padding_all(10),
			child_gap = 10,
			layout_direction = .Left_To_Right,
			background_fill = base.fill_color(0, 0, 255),
			capability_flags = ui.Capability_Flags{.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.text(
				ctx,
				"text",
				"one two three four five six seven eight  nine ten",
				ui.Style {
					sizing_x = ui.sizing_grow(min = 100, max = 100),
					sizing_y = ui.sizing_grow(min = 30),
				},
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_nested_text_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.container(
		ctx,
		"parent",
		ui.Style {
			sizing_x = ui.sizing_fit(min = 430, max = 630),
			sizing_y = ui.sizing_fit(),
			padding = ui.padding_all(16),
			layout_direction = .Top_To_Bottom,
			alignment_x = .Center,
			child_gap = 16,
			background_fill = base.fill_color(102, 51, 153),
			capability_flags = ui.Capability_Flags{.Background},
		},
		proc(ctx: ^ui.Context) {
			ui.container(
				ctx,
				"grow",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fit(min = 80),
					padding = ui.padding_xy(16, 32),
					child_gap = 32,
					alignment_x = .Left,
					alignment_y = .Center,
					background_fill = base.fill_color(255, 0, 0),
					capability_flags = ui.Capability_Flags{.Background},
					clip = ui.Clip_Config{{true, false}},
				},
				proc(ctx: ^ui.Context) {
					ui.container(
						ctx,
						"fit",
						ui.Style {
							sizing_x = ui.sizing_fit(),
							sizing_y = ui.sizing_fit(),
							background_fill = base.fill_color(157, 125, 172),
							capability_flags = ui.Capability_Flags{.Background},
						},
						proc(ctx: ^ui.Context) {
							ui.text(ctx, "text", "one two three four")
						},
					)
				},
			)
		},
	)
	ui.end(ctx)
}


Complex_UI_Data :: struct {
	items:             [5]string,
	item_texture_idxs: [5]int,
	idx:               int,
	builder:           strings.Builder,
}

build_complex_ui :: proc(app_state: ^App_State, complex_ui_data: ^Complex_UI_Data) {
	buf: [1024]u8
	builder := strings.builder_from_bytes(buf[:])
	complex_ui_data.builder = builder
	ctx := &app_state.ctx

	ui.begin(ctx)

	ui.container(
		ctx,
		"parent",
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			padding = ui.padding_all(16),
			layout_direction = .Top_To_Bottom,
			alignment_x = .Center,
			child_gap = 16,
			background_fill = base.fill_color(102, 51, 153),
			capability_flags = ui.Capability_Flags{.Background},
		},
		complex_ui_data,
		proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {

			for item, idx in data.items {
				data.idx = idx
				ui.container(
					ctx,
					item,
					ui.Style {
						sizing_x = ui.sizing_grow(),
						sizing_y = ui.sizing_fit(min = 80),
						padding = ui.padding_xy(16, 32),
						child_gap = 32,
						alignment_x = .Left,
						alignment_y = .Center,
						border_radius = ui.border_radius_all(4),
						background_fill = base.fill_color(255, 125, 172),
						clip = ui.Clip_Config{{true, true}},
						capability_flags = ui.Capability_Flags{.Background},
					},
					data,
					proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {

						strings.write_int(&data.builder, data.idx)
						id := strings.to_string(data.builder)

						// Config for the text container
						ui.container(
							ctx,
							id,
							ui.Style{sizing_x = ui.sizing_grow(), sizing_y = ui.sizing_grow()},
							data,
							proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {
								item := data.items[data.idx]
								strings.write_int(&data.builder, len(data.items) + data.idx)
								text_id := strings.to_string(data.builder)
								ui.text(
									ctx,
									text_id,
									item,
									ui.Style{text_alignment_x = .Left, text_alignment_y = .Center},
								)
							},
						)

						strings.write_int(&data.builder, len(data.items) + data.idx + 13 * 100)
						image_id := strings.to_string(data.builder)

						// Config for the image container - content set after element creation
						if img_elem, ok := ui.open_element(
							ctx,
							image_id,
							ui.Style {
								sizing_x = ui.sizing_fixed(64),
								sizing_y = ui.sizing_fixed(64),
								capability_flags = ui.Capability_Flags{.Image},
							},
						); ok {
							img_elem.config.content.image_data = rawptr(
								&data.item_texture_idxs[data.idx],
							)
							ui.close_element(ctx)
						}
					},
				)
			}
		},
	)
	ui.end(ctx)
}

process_events :: proc(app_state: ^App_State) {
	// Process input
	event := sdl.Event{}
	for sdl.PollEvent(&event) {
		backend.enqueue_sdl_event(&app_state.backend_ctx.io, event)
		#partial switch event.type {
		case .KEYUP:
			#partial switch event.key.keysym.sym {
			case .ESCAPE:
				app_state.running = false
			}
		case .QUIT:
			app_state.running = false
		}
	}
}
