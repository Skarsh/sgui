package main

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Data :: struct {
	tex_id: ui.Texture_Id,
}

// --- Style Palette ---
WINDOW_BG :: base.Color{30, 30, 30, 255}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {

	if ui.begin(ctx) {
		// --- Global Style Scope ---

		ui.push_style(ctx, ui.Style{background_fill = WINDOW_BG})
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
				padding = ui.padding_all(15),
			},
		) {

			// --- Image widget ---
			ui.image(
				ctx,
				"image",
				data.tex_id,
				style = ui.Style {
					sizing_x = ui.sizing_percent(1.0),
					sizing_y = ui.sizing_percent(1.0),
					background_fill = base.fill_color(255, 165, 0),
					capability_flags = ui.Capability_Flags{.Background},
				},
			)

			ui.end_container(ctx)
		}
		ui.end(ctx)
	}
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) -> bool {
	if base.is_key_pressed(ctx.input^, base.Key.Escape) {
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
	arena_err := virtual.arena_init_static(&arena, 20 * mem.Megabyte)
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
		title = "Image Example App",
		window_size = {640, 480},
		font_path = "",
		font_id = 0,
		font_size = 48,
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			poll_events = backend.sdl_poll_events,
		},
		window_api = backend.create_sdl_window_api(),
		memory = app_memory,
	}

	image_app, image_app_ok := app.init(config)
	if !image_app_ok {
		log.error("Failed to initializze GUI application")
		return
	}

	defer app.deinit(image_app)

	// TODO(Thomas): Shouldn't this should at least be graphics backend agnostic
	// Load textures (must be after app.init since OpenGL context is needed)
	// NOTE(Thomas): This uses the ui library opengl backend for creating a texture from a file.
	// This should be replaced with your own backend, which for now has to be OpenGL.
	tex, tex_ok := backend.opengl_create_texture_from_file("data/textures/copy_icon.png")
	assert(tex_ok)
	defer backend.opengl_delete_texture(&tex.id)

	data := Data {
		tex_id = ui.Texture_Id(tex.id),
	}

	app.run(image_app, &data, update_and_draw)
}
