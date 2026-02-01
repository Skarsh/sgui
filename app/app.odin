package app

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../backend"
import "../base"
import "../ui"

App :: struct {
	app_arena:            virtual.Arena,
	persistent_allocator: mem.Allocator,
	frame_arena:          virtual.Arena,
	draw_cmd_arena:       virtual.Arena,
	io_arena:             virtual.Arena,
	ui_ctx:               ui.Context,
	backend_ctx:          backend.Context,
	input:                base.Input,
	running:              bool,
}

App_Memory :: struct {
	app_arena_mem:      []u8,
	frame_arena_mem:    []u8,
	draw_cmd_arena_mem: []u8,
	io_arena_mem:       []u8,
}

App_Config :: struct {
	title:       string,
	window_size: base.Vector2i32,
	font_path:   string,
	font_id:     u16,
	font_size:   f32,
	allocator:   mem.Allocator,
	memory:      App_Memory,
}

init :: proc(app_config: App_Config) -> (^App, bool) {
	app, app_err := new(App)
	assert(app_err == .None)
	if app_err != .None {
		return nil, false
	}

	arena_err := virtual.arena_init_buffer(&app.app_arena, app_config.memory.app_arena_mem)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate app arena")
		free(app)
		return nil, false
	}
	app_arena_allocator := virtual.arena_allocator(&app.app_arena)

	persistent_allocator := context.allocator


	arena_err = virtual.arena_init_buffer(&app.frame_arena, app_config.memory.frame_arena_mem)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate frame arena")
		free(app)
		return nil, false
	}
	frame_arena_allocator := virtual.arena_allocator(&app.frame_arena)

	arena_err = virtual.arena_init_buffer(
		&app.draw_cmd_arena,
		app_config.memory.draw_cmd_arena_mem,
	)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocator draw_cmd_arena")
		free(app)
		return nil, false
	}
	draw_cmd_arena_allocator := virtual.arena_allocator(&app.draw_cmd_arena)

	arena_err = virtual.arena_init_buffer(&app.io_arena, app_config.memory.io_arena_mem)
	assert(arena_err == .None)
	if arena_err != .None {
		log.error("Failed to allocate io arena")
		free(app)
		return nil, false
	}
	io_arena_allocator := virtual.arena_allocator(&app.io_arena)

	ui.init(
		&app.ui_ctx,
		&app.input,
		persistent_allocator,
		frame_arena_allocator,
		draw_cmd_arena_allocator,
		app_config.window_size,
		app_config.font_id,
		app_config.font_size,
	)

	// TODO(Thomas): This should come in from the app user instead, so they can implement their own
	// backend if they want eventually.
	platform_api := backend.Platform_API {
		get_perf_counter = backend.sdl_get_perf_counter,
		get_perf_freq    = backend.sdl_get_perf_freq,
		poll_events      = backend.sdl_poll_events,
	}

	backend_init_ok := backend.init_ctx(
		&app.backend_ctx,
		&app.ui_ctx,
		&app.input,
		app_config.title,
		app_config.window_size,
		app_config.font_size,
		platform_api,
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
		if backend.process(&app.backend_ctx) {
			app.running = false
		}

		// Update window size in ui Context
		ui.window_resize(&app.ui_ctx, app.backend_ctx.window.size)

		// TODO(Thomas): This feels wrong, shouldn't have to call the ui package here
		if base.is_key_pressed(app.ui_ctx.input^, base.Key.Escape) {
			app.running = false
		}

		// 3. Rendering
		backend.render_begin(&app.backend_ctx.render_ctx)
		update_proc(&app.ui_ctx, app_data)
		backend.render_end(&app.backend_ctx.render_ctx, app.ui_ctx.command_queue[:])

		// 4. TODO(Thomas): Sleep to hit target framerate if not vsync.
		// currently hardcoded to use vsync, so no sleeping.
	}
}
