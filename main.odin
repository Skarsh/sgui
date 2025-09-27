package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import sdl "vendor:sdl2"

import "backend"
import "base"
import "ui"

// This example uses SDL2, but the immediate mode ui library should be
// rendering and windowing agnostic

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	logger := log.create_console_logger(log.Level.Info)
	context.logger = logger
	defer log.destroy_console_logger(logger)

	if sdl.Init(sdl.INIT_VIDEO) < 0 {
		log.error("Unable to init SDL: ", sdl.GetError())
		return
	}

	defer sdl.Quit()

	window := sdl.CreateWindow(
		"ImGUI",
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		{.SHOWN, .RESIZABLE, .OPENGL},
	)

	if window == nil {
		log.error("Unable to create window: ", sdl.GetError())
		return
	}

	ctx := ui.Context{}

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
		{WINDOW_WIDTH, WINDOW_HEIGHT},
		font_id,
		font_size,
	)
	defer ui.deinit(&ctx)

	texture_paths := []string {
		"./data/textures/skarsh_logo_192x192.png",
		"./data/textures/copy_icon.png",
		"./data/textures/paste_icon.png",
		"./data/textures/delete_icon.png",
		"./data/textures/comment_icon.png",
		"./data/textures/cut_icon.png",
	}

	backend_ctx := backend.Context{}
	backend.init_ctx(
		&backend_ctx,
		&ctx,
		window,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		texture_paths,
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
		build_styled_ui(&app_state)
		//build_percentage_of_parent_ui(&app_state)
		//build_resize_bug_repro(&app_state)
		//build_grow_ui(&app_state)
		//build_multiple_images_ui(&app_state, &image_data)

		backend.render_end(&app_state.backend_ctx.render_ctx, app_state.ctx.command_queue[:])

		sdl.Delay(10)
	}
}

App_State :: struct {
	window:      ^sdl.Window,
	window_size: [2]i32,
	ctx:         ui.Context,
	backend_ctx: backend.Context,
	running:     bool,
}

deinit_app_state :: proc(app_state: ^App_State) {
	backend.deinit(&app_state.backend_ctx)
	sdl.DestroyWindow(app_state.window)
}

Image_Data :: struct {
	tex_1: i32,
	tex_2: i32,
	tex_3: i32,
	tex_4: i32,
	tex_5: i32,
}

build_multiple_images_ui :: proc(app_state: ^App_State, image_data: ^Image_Data) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_background_fill(ctx, base.Color{255, 255, 255, 255}); defer ui.pop_background_fill(ctx)

	main_container_sizing := ui.Sizing {
		kind = .Grow,
	}
	ui.container(
		ctx,
		"main_container",
		ui.Config_Options{layout = {sizing = {&main_container_sizing, &main_container_sizing}}},
		image_data,
		proc(ctx: ^ui.Context, data: ^Image_Data) {

			ui.push_sizing_x(
				ctx,
				ui.Sizing{kind = .Fixed, value = 256},
			); defer ui.pop_sizing_x(ctx)
			ui.push_sizing_y(
				ctx,
				ui.Sizing{kind = .Fixed, value = 256},
			); defer ui.pop_sizing_x(ctx)

			ui.push_capability_flags(
				ctx,
				ui.Capability_Flags{.Image},
			); defer ui.pop_capability_flags(ctx)


			ui.container(
				ctx,
				"image_1",
				ui.Config_Options{content = {image_data = rawptr(&data.tex_1)}},
			)

			ui.container(
				ctx,
				"image_2",
				ui.Config_Options{content = {image_data = rawptr(&data.tex_2)}},
			)

			ui.container(
				ctx,
				"image_3",
				ui.Config_Options{content = {image_data = rawptr(&data.tex_3)}},
			)

			ui.container(
				ctx,
				"image_4",
				ui.Config_Options{content = {image_data = rawptr(&data.tex_4)}},
			)

			ui.container(
				ctx,
				"image_5",
				ui.Config_Options{content = {image_data = rawptr(&data.tex_5)}},
			)
		},
	)

	ui.end(ctx)
}

build_resize_bug_repro :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)

	ui.push_background_fill(ctx, base.Color{75, 75, 30, 255}); defer ui.pop_background_fill(ctx)
	ui.push_layout_direction(ctx, .Left_To_Right); defer ui.pop_layout_direction(ctx)

	parent_sizing := [2]ui.Sizing{{kind = .Fixed, value = 500}, {kind = .Fixed, value = 500}}
	ui.container(
		ctx,
		"parent",
		ui.Config_Options{layout = {sizing = {&parent_sizing.x, &parent_sizing.y}}},
		proc(ctx: ^ui.Context) {
			ui.push_background_fill(
				ctx,
				base.Color{255, 75, 30, 255},
			); defer ui.pop_background_fill(ctx)
			child_1_sizing := [2]ui.Sizing{{kind = .Grow, min_value = 250}, {kind = .Grow}}
			ui.container(
				ctx,
				"child_1",
				ui.Config_Options{layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}}},
			)

			ui.push_background_fill(
				ctx,
				base.Color{30, 75, 255, 255},
			); defer ui.pop_background_fill(ctx)
			child_2_sizing := [2]ui.Sizing{{kind = .Grow, value = 350}, {kind = .Grow}}

			ui.container(
				ctx,
				"child_2",
				ui.Config_Options{layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}}},
			)
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

	ui.push_background_fill(ctx, base.Color{255, 0, 0, 255}); defer ui.pop_background_fill(ctx)

	// Child 1
	child_1_sizing := [2]ui.Sizing {
		{kind = .Percentage_Of_Parent, value = 0.5},
		{kind = .Percentage_Of_Parent, value = 0.5},
	}
	ui.container(
		ctx,
		"child_1",
		ui.Config_Options{layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}}},
	)

	ui.push_background_fill(ctx, base.Color{0, 0, 255, 255}); defer ui.pop_background_fill(ctx)

	// Child 2
	child_2_sizing := [2]ui.Sizing {
		{kind = .Percentage_Of_Parent, value = 0.5},
		{kind = .Percentage_Of_Parent, value = 0.5},
	}
	ui.container(
		ctx,
		"child_2",
		ui.Config_Options{layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}}},
	)

	ui.end(ctx)
}

build_grow_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)
	sizing := [2]ui.Sizing{ui.Sizing{kind = .Fixed, value = 400}, ui.Sizing{kind = .Fit}}
	padding := ui.Padding{10, 10, 10, 10}
	child_gap: f32 = 10
	background_fill := base.Fill(base.Color{255, 255, 255, 255})

	ui.push_capability_flags(
		ctx,
		ui.Capability_Flags{.Background},
	); defer ui.pop_capability_flags(ctx)
	ui.container(
		&app_state.ctx,
		"parent",
		ui.Config_Options {
			layout = {sizing = {&sizing.x, &sizing.y}, padding = &padding, child_gap = &child_gap},
			background_fill = &background_fill,
		},
		proc(ctx: ^ui.Context) {
			child_1_sizing := [2]ui.Sizing {
				ui.Sizing{kind = .Grow},
				ui.Sizing{kind = .Fixed, value = 100},
			}
			child_1_background_fill := base.Fill(base.Color{255, 0, 0, 255})


			ui.container(
				ctx,
				"child_1",
				ui.Config_Options {
					layout = {sizing = {&child_1_sizing.x, &child_1_sizing.y}},
					background_fill = &child_1_background_fill,
				},
			)

			child_2_sizing := [2]ui.Sizing {
				ui.Sizing{kind = .Fixed, value = 100},
				ui.Sizing{kind = .Fixed, value = 100},
			}
			child_2_background_fill := base.Fill(base.Color{0, 255, 0, 255})

			ui.container(
				ctx,
				"child_2",
				ui.Config_Options {
					layout = {sizing = {&child_2_sizing.x, &child_2_sizing.y}},
					background_fill = &child_2_background_fill,
				},
			)

			child_3_sizing := [2]ui.Sizing {
				ui.Sizing{kind = .Grow, max_value = 50},
				ui.Sizing{kind = .Grow},
			}
			child_3_background_fill := base.Fill(base.Color{0, 0, 255, 255})

			ui.container(
				ctx,
				"child_3",
				ui.Config_Options {
					layout = {sizing = {&child_3_sizing.x, &child_3_sizing.y}},
					background_fill = &child_3_background_fill,
				},
			)

		},
	)
	ui.end(ctx)
}

build_styled_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	ui.push_background_fill(ctx, base.Color{25, 25, 30, 255}); defer ui.pop_background_fill(ctx)
	ui.push_padding(ctx, {20, 20, 20, 20}); defer ui.pop_padding(ctx)
	ui.push_layout_direction(ctx, .Top_To_Bottom); defer ui.pop_layout_direction(ctx)
	ui.push_child_gap(ctx, 15); defer ui.pop_child_gap(ctx)

	ui.push_sizing_x(ctx, {kind = .Grow}); defer ui.pop_sizing_x(ctx)
	ui.push_sizing_y(ctx, {kind = .Fit}); defer ui.pop_sizing_y(ctx)

	ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
	ui.push_border_thickness(ctx, 5); defer ui.pop_border_thickness(ctx)

	//ui.push_border_fill(
	//	ctx,
	//	base.Gradient{{53, 0, 104, 230}, {255, 105, 120, 210}, {0, 1}},
	//); defer ui.pop_border_fill(ctx)

	ui.push_border_fill(
		ctx,
		base.Fill(base.Color{255, 255, 0, 255}),
	); defer ui.pop_border_fill(ctx)

	main_container_sizing := ui.Sizing {
		kind  = .Percentage_Of_Parent,
		value = 1.0,
	}

	ui.container(
		ctx,
		"main_container",
		ui.Config_Options{layout = {sizing = {&main_container_sizing, &main_container_sizing}}},
		proc(ctx: ^ui.Context) {

			ui.text(
				ctx,
				"title",
				"Themed UI Demo",
				text_fill = base.Color{230, 230, 230, 255},
				text_padding = ui.Padding{5, 5, 5, 5},
			)

			{
				ui.push_background_fill(
					ctx,
					base.Color{80, 50, 60, 255},
				); defer ui.pop_background_fill(ctx)
				ui.push_padding(ctx, {10, 10, 10, 10}); defer ui.pop_padding(ctx)
				ui.push_layout_direction(ctx, .Left_To_Right); defer ui.pop_layout_direction(ctx)

				ui.push_capability_flags(ctx, {.Background}); defer ui.pop_capability_flags(ctx)
				ui.push_corner_radius(ctx, 10); defer ui.pop_corner_radius(ctx)
				ui.push_clip_config(ctx, {{true, true}}); defer ui.pop_clip_config(ctx)

				ui.push_border_thickness(ctx, 2); defer ui.pop_border_thickness(ctx)
				ui.container(ctx, "button_panel", proc(ctx: ^ui.Context) {

					ui.push_background_fill(
						ctx,
						base.Gradient{{53, 0, 104, 230}, {255, 105, 120, 210}, {0, 1}},
					); defer ui.pop_background_fill(ctx)
					ui.button(ctx, "button1", "Button A")

					ui.push_background_fill(
						ctx,
						base.Gradient{{81, 163, 163, 255}, {117, 72, 94, 210}, {0, 1}},
					); defer ui.pop_background_fill(ctx)
					ui.button(ctx, "button2", "Button B")

					ui.push_background_fill(
						ctx,
						base.Color{150, 50, 50, 255},
					); defer ui.pop_background_fill(ctx)

					ui.push_background_fill(
						ctx,
						base.Color{255, 144, 101, 255},
					); defer ui.pop_background_fill(ctx)
					text_fill := base.Fill(base.Color{255, 255, 255, 255})
					ui.button(ctx, "button3", "Danger Button", {text_fill = &text_fill})
					ui.pop_background_fill(ctx)
				})
			}

			ui.text(
				ctx,
				"footer_text",
				"The styles above were scoped.",
				text_fill = base.Color{150, 150, 150, 255},
			)
		},
	)

	ui.end(ctx)
}

build_interactive_button_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)
	sizing := ui.Sizing {
		kind  = ui.Size_Kind.Percentage_Of_Parent,
		value = 1.0,
	}

	ui.push_padding(ctx, ui.Padding{10, 10, 10, 10}); defer ui.pop_padding(ctx)
	ui.push_child_gap(ctx, 10); defer ui.pop_child_gap(ctx)
	ui.push_capability_flags(ctx, ui.Capability_Flags{.Background})

	background_fill := base.Fill(base.Color{48, 200, 128, 255})
	clip := ui.Clip_Config{{true, true}}

	ui.container(
		&app_state.ctx,
		"container",
		ui.Config_Options {
			layout = {sizing = {&sizing, &sizing}},
			background_fill = &background_fill,
			clip = &clip,
		},
		proc(ctx: ^ui.Context) {
			comm := ui.button(ctx, "button1", "Button 1")
			if comm.active {
				sizing := ui.Sizing {
					kind = .Grow,
				}
				layout_direction := ui.Layout_Direction.Top_To_Bottom
				background_fill := base.Fill(base.Color{75, 75, 75, 255})
				ui.container(
					ctx,
					"panel",
					ui.Config_Options {
						layout = {
							sizing = {&sizing, &sizing},
							layout_direction = &layout_direction,
						},
						background_fill = &background_fill,
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
	sizing := ui.Sizing {
		kind = .Fit,
	}
	padding := ui.Padding{10, 10, 10, 10}
	child_gap: f32 = 10
	layout_direction := ui.Layout_Direction.Left_To_Right
	background_fill := base.Fill(base.Color{0, 0, 255, 255})
	capability_flags := ui.Capability_Flags{.Background}

	ui.container(
		ctx,
		"text_container",
		ui.Config_Options {
			layout = {
				sizing = {&sizing, &sizing},
				padding = &padding,
				child_gap = &child_gap,
				layout_direction = &layout_direction,
			},
			background_fill = &background_fill,
			capability_flags = &capability_flags,
		},
		proc(ctx: ^ui.Context) {
			ui.text(
				ctx,
				"text",
				"one two three four five six seven eight  nine ten",
				min_width = 100,
				max_width = 100,
				min_height = 30,
			)
		},
	)
	ui.end(&app_state.ctx)
}

build_nested_text_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx
	ui.begin(ctx)

	parent_sizing_x := ui.Sizing {
		kind      = .Fit,
		min_value = 430,
		max_value = 630,
	}
	parent_sizing_y := ui.Sizing {
		kind = .Fit,
	}
	parent_padding := ui.Padding{16, 16, 16, 16}
	parent_dir := ui.Layout_Direction.Top_To_Bottom
	parent_align_x := ui.Alignment_X.Center
	parent_gap: f32 = 16
	parent_bg_fill := base.Fill(base.Color{102, 51, 153, 255})
	parent_cap_flags := ui.Capability_Flags{.Background}

	ui.container(
		ctx,
		"parent",
		ui.Config_Options {
			layout = {
				sizing = {&parent_sizing_x, &parent_sizing_y},
				padding = &parent_padding,
				layout_direction = &parent_dir,
				alignment_x = &parent_align_x,
				child_gap = &parent_gap,
			},
			background_fill = &parent_bg_fill,
			capability_flags = &parent_cap_flags,
		},
		proc(ctx: ^ui.Context) {
			grow_sizing_x := ui.Sizing {
				kind = .Grow,
			}
			grow_sizing_y := ui.Sizing {
				kind      = .Fit,
				min_value = 80,
			}
			grow_padding := ui.Padding{32, 32, 16, 16}
			grow_gap: f32 = 32
			grow_align_x := ui.Alignment_X.Left
			grow_align_y := ui.Alignment_Y.Center
			grow_bg_fill := base.Fill(base.Color{255, 0, 0, 255})
			grow_cap_flags := ui.Capability_Flags{.Background}
			grow_clip := ui.Clip_Config{{true, false}}

			ui.container(
				ctx,
				"grow",
				ui.Config_Options {
					layout = {
						sizing = {&grow_sizing_x, &grow_sizing_y},
						padding = &grow_padding,
						child_gap = &grow_gap,
						alignment_x = &grow_align_x,
						alignment_y = &grow_align_y,
					},
					background_fill = &grow_bg_fill,
					capability_flags = &grow_cap_flags,
					clip = &grow_clip,
				},
				proc(ctx: ^ui.Context) {
					fit_sizing := ui.Sizing {
						kind = .Fit,
					}
					fit_bg_fill := base.Fill(base.Color{157, 125, 172, 255})
					fit_cap_flags := ui.Capability_Flags{.Background}

					ui.container(
						ctx,
						"fit",
						ui.Config_Options {
							layout = {sizing = {&fit_sizing, &fit_sizing}},
							background_fill = &fit_bg_fill,
							capability_flags = &fit_cap_flags,
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

	parent_sizing_x := ui.Sizing {
		kind  = .Percentage_Of_Parent,
		value = 1.0,
	}
	parent_sizing_y := ui.Sizing {
		kind  = .Percentage_Of_Parent,
		value = 1.0,
	}
	parent_padding := ui.Padding{16, 16, 16, 16}
	parent_dir := ui.Layout_Direction.Top_To_Bottom
	parent_align_x := ui.Alignment_X.Center
	parent_gap: f32 = 16
	parent_bg_fill := base.Fill(base.Color{102, 51, 153, 255})
	parent_cap_flags := ui.Capability_Flags{.Background}

	ui.container(
		ctx,
		"parent",
		ui.Config_Options {
			layout = {
				sizing = {&parent_sizing_x, &parent_sizing_y},
				padding = &parent_padding,
				layout_direction = &parent_dir,
				alignment_x = &parent_align_x,
				child_gap = &parent_gap,
			},
			background_fill = &parent_bg_fill,
			capability_flags = &parent_cap_flags,
		},
		complex_ui_data,
		proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {

			item_sizing_x := ui.Sizing {
				kind = .Grow,
			}
			item_sizing_y := ui.Sizing {
				kind      = .Fit,
				min_value = 80,
			}
			item_padding := ui.Padding{32, 32, 16, 16}
			item_gap: f32 = 32
			item_align_x := ui.Alignment_X.Left
			item_align_y := ui.Alignment_Y.Center
			item_corner_radius: f32 = 4
			item_bg_fill := base.Fill(base.Color{255, 125, 172, 255})
			item_clip := ui.Clip_Config{{true, true}}
			item_cap_flags := ui.Capability_Flags{.Background}

			for item, idx in data.items {
				data.idx = idx
				ui.container(
					ctx,
					item,
					ui.Config_Options {
						layout = {
							sizing = {&item_sizing_x, &item_sizing_y},
							padding = &item_padding,
							child_gap = &item_gap,
							alignment_x = &item_align_x,
							alignment_y = &item_align_y,
							corner_radius = &item_corner_radius,
						},
						background_fill = &item_bg_fill,
						clip = &item_clip,
						capability_flags = &item_cap_flags,
					},
					data,
					proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {

						strings.write_int(&data.builder, data.idx)
						id := strings.to_string(data.builder)

						// Config for the text container
						text_sizing_grow := ui.Sizing {
							kind = .Grow,
						}
						ui.container(
							ctx,
							id,
							ui.Config_Options {
								layout = {sizing = {&text_sizing_grow, &text_sizing_grow}},
							},
							data,
							proc(ctx: ^ui.Context, data: ^Complex_UI_Data) {
								item := data.items[data.idx]
								strings.write_int(&data.builder, len(data.items) + data.idx)
								text_id := strings.to_string(data.builder)
								ui.text(
									ctx,
									text_id,
									item,
									text_alignment_x = .Left,
									text_alignment_y = .Center,
								)
							},
						)

						strings.write_int(&data.builder, len(data.items) + data.idx + 13 * 100)
						image_id := strings.to_string(data.builder)

						// Config for the image container
						image_sizing := ui.Sizing {
							kind  = .Fixed,
							value = 64,
						}
						image_cap_flags := ui.Capability_Flags{.Image}
						ui.container(
							ctx,
							image_id,
							ui.Config_Options {
								layout = {sizing = {&image_sizing, &image_sizing}},
								capability_flags = &image_cap_flags,
								content = {image_data = rawptr(&data.item_texture_idxs[data.idx])},
							},
						)
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
