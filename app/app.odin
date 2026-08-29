package app

import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../backend"
import "../base"
import "../text"
import "../ui"

_on_quit_callback :: proc(user_data: rawptr) {
	app := (^App)(user_data)
	app.running = false
}

App :: struct {
	persistent_allocator: mem.Allocator,
	app_arena:            virtual.Arena,
	frame_arena:          virtual.Arena,
	ui_ctx:               ui.Context,
	backend_ctx:          backend.Context,
	input:                base.Input,
	text_measurement:     text.Text_Measurement,
	running:              bool,
}

App_Memory :: struct {
	app_arena_mem:       []u8,
	frame_arena_mem:     []u8,
	draw_command_buffer: []ui.Draw_Command,
}

App_Config :: struct {
	title:        cstring,
	window_size:  base.Vector2i32,
	font_configs: []base.Font_Config,
	platform_api: backend.Platform_API,
	window_api:   backend.Window_API,
	allocator:    mem.Allocator,
	memory:       App_Memory,
}

init :: proc(app_config: App_Config) -> (^App, bool) {

	if len(app_config.memory.draw_command_buffer) == 0 {
		log.error("Draw command buffer cannot be empty")
		return nil, false
	}

	allocator := app_config.allocator

	app, app_err := new(App, allocator)
	if app_err != .None {
		return nil, false
	}

	// Frees up app if any of the frame arenas failed ot init
	// at the end of the scope.
	success := false
	defer {
		if !success {
			free(app, allocator)
		}
	}

	app.persistent_allocator = app_config.allocator

	app_allocator, app_arena_ok := init_arena(
		&app.app_arena,
		app_config.memory.app_arena_mem,
		"app_arena",
	)
	if !app_arena_ok {
		return nil, false
	}

	frame_allocator, frame_arena_ok := init_arena(
		&app.frame_arena,
		app_config.memory.frame_arena_mem,
		"frame_arena",
	)
	if !frame_arena_ok {
		return nil, false
	}

	app_callbacks := backend.App_Callbacks {
		on_quit      = _on_quit_callback,
		on_quit_data = app,
	}

	backend_init_ok := backend.init_ctx(
		&app.backend_ctx,
		&app.input,
		&app.text_measurement,
		app_config.title,
		app_config.window_size,
		app_config.font_configs,
		app_config.platform_api,
		app_config.window_api,
		app_callbacks,
		app_allocator,
	)

	if !backend_init_ok {
		free_all(app_allocator)
		return nil, false
	}

	ui.init(
		&app.ui_ctx,
		&app.input,
		&app.text_measurement,
		app.persistent_allocator,
		frame_allocator,
		app_config.memory.draw_command_buffer,
		app_config.window_size,
		app_config.font_configs,
	)

	app.running = true
	success = true
	return app, true
}

deinit :: proc(app: ^App) {
	ui.deinit(&app.ui_ctx)
	backend.deinit(&app.backend_ctx)
	free_all(virtual.arena_allocator(&app.app_arena))
	free(app, app.persistent_allocator)
}

run :: proc(app: ^App, app_data: $T, update_proc: proc(ctx: ^ui.Context, app_data: T) -> bool) {
	for app.running {

		// 1. Timing
		backend.time(&app.backend_ctx.io)
		app.ui_ctx.dt = app.backend_ctx.io.frame_time.dt

		// 2. Event processing
		backend.process(&app.backend_ctx)

		// Break out of the run loop if on_quit callback has been called.
		if !app.running {
			break
		}

		// Update window size in ui Context
		ui.window_resize(&app.ui_ctx, app.backend_ctx.window.size)

		// 3. Rendering
		backend.render_begin(&app.backend_ctx.render_ctx)
		keep_running := update_proc(&app.ui_ctx, app_data)
		if !keep_running {
			app.running = false
		}

		backend.render_end(&app.backend_ctx.render_ctx, ui.draw_commands(&app.ui_ctx))

		// 4. TODO(Thomas): Sleep to hit target framerate if not vsync.
		// currently hardcoded to use vsync, so no sleeping.
	}
}

@(private)
init_arena :: proc(arena: ^virtual.Arena, buffer: []u8, name: string) -> (mem.Allocator, bool) {
	if err := virtual.arena_init_buffer(arena, buffer); err != .None {
		log.errorf("Failed to initialize %s: %v", name, err)
		return {}, false
	}

	return virtual.arena_allocator(arena), true
}
