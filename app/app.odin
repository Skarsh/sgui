package app

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../backend"
import "../ui"
import sdl "vendor:sdl2"

App :: struct {
	app_arena:        virtual.Arena,
	persistent_arena: virtual.Arena,
	frame_arena:      virtual.Arena,
	io_arena:         virtual.Arena,
	window:           backend.Window,
	ui_ctx:           ui.Context,
	backend_ctx:      backend.Context,
	running:          bool,
}

App_Config :: struct {
	title:     string,
	width:     i32,
	height:    i32,
	font_path: string,
	font_id:   u16,
	font_size: f32,
}

init :: proc(app_config: App_Config) -> (^App, bool) {
	app, app_err := new(App)
	assert(app_err == .None)
	if app_err != .None {
		return nil, false
	}

	arena_err := virtual.arena_init_static(&app.app_arena, 10 * mem.Megabyte)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate app arena")
		free(app)
		return nil, false
	}
	app_arena_allocator := virtual.arena_allocator(&app.app_arena)

	arena_err = virtual.arena_init_static(&app.persistent_arena, 100 * mem.Kilobyte)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate persistent arena")
		free(app)
		return nil, false
	}
	persistent_arena_allocator := virtual.arena_allocator(&app.persistent_arena)

	arena_err = virtual.arena_init_static(&app.frame_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate frame arena")
		free(app)
		return nil, false
	}
	frame_arena_allocator := virtual.arena_allocator(&app.frame_arena)

	arena_err = virtual.arena_init_static(&app.io_arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate io arena")
		free(app)
		return nil, false
	}
	io_arena_allocator := virtual.arena_allocator(&app.io_arena)

	window, window_ok := backend.init_and_create_window(
		"ImGUI",
		app_config.width,
		app_config.height,
	)
	assert(window_ok)
	if !window_ok {
		free(app)
		return nil, false
	}

	app.window = window

	ui.init(
		&app.ui_ctx,
		persistent_arena_allocator,
		frame_arena_allocator,
		{app_config.width, app_config.height},
		app_config.font_id,
		app_config.font_size,
	)

	backend_init_ok := backend.init_ctx(
		&app.backend_ctx,
		&app.ui_ctx,
		app.window,
		app_config.width,
		app_config.height,
		app_config.font_size,
		app_arena_allocator,
		io_arena_allocator,
	)
	assert(backend_init_ok)
	if !backend_init_ok {
		free(app)
		return nil, false
	}

	app.running = true

	return app, true
}

deinit :: proc(app: ^App) {
	ui.deinit(&app.ui_ctx)
	backend.deinit(&app.backend_ctx)
	free(app)
}

run :: proc(app: ^App, app_data: $T, update_proc: proc(ctx: ^ui.Context, app_data: T)) {
	for app.running {

		// 1. Timing
		backend.time(&app.backend_ctx.io)
		app.ui_ctx.dt = app.backend_ctx.io.frame_time.dt

		// 2. Event processing
		// TODO(Thomas): Shouldn't use sdl directly here
		event := sdl.Event{}
		for sdl.PollEvent(&event) {
			backend.enqueue_sdl_event(&app.backend_ctx.io, event)
			#partial switch event.type {
			case .QUIT:
				app.running = false
			}
		}
		backend.process_events(&app.backend_ctx, &app.ui_ctx)

		// TODO(Thomas): This feels wrong, shouldn't have to call the ui package here
		if ui.is_key_pressed(app.ui_ctx, ui.Key.Escape) {
			app.running = false
		}

		// 3. Rendering
		backend.render_begin(&app.backend_ctx.render_ctx)
		update_proc(&app.ui_ctx, app_data)
		backend.render_end(&app.backend_ctx.render_ctx, app.ui_ctx.command_queue[:])

		// TODO(Thomas): Shouldn't use sdl directly here
		sdl.Delay(10)
	}
}
