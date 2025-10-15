package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import backend "../../backend"
import base "../../base"
import ui "../../ui"
import sdl "vendor:sdl2"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

Data :: struct {
	counter: int,
	sb:      strings.Builder,
}

App_State :: struct {
	window:      backend.Window,
	window_size: [2]i32,
	ctx:         ui.Context,
	backend_ctx: backend.Context,
	running:     bool,
	data:        Data,
}

deinit_app_state :: proc(app_state: ^App_State) {
	backend.deinit(&app_state.backend_ctx)
}

build_ui :: proc(app_state: ^App_State) {
	ctx := &app_state.ctx

	ui.begin(ctx)

	ui.push_capability_flags(ctx, ui.Capability_Flags{.Background})

	ui.push_border_thickness(ctx, 5); defer ui.pop_border_thickness(ctx)
	ui.push_corner_radius(ctx, 5); defer ui.pop_corner_radius(ctx)
	ui.push_border_fill(ctx, base.Fill(base.Color{24, 36, 55, 255})); defer ui.pop_border_fill(ctx)

	ui.push_alignment_x(ctx, .Center); defer ui.pop_alignment_x(ctx)
	ui.push_alignment_y(ctx, .Center); defer ui.pop_alignment_y(ctx)
	ui.push_text_alignment_x(ctx, .Center); defer ui.pop_text_alignment_x(ctx)
	ui.push_text_alignment_y(ctx, .Center); defer ui.pop_text_alignment_y(ctx)

	main_container_sizing := [2]ui.Sizing {
		{kind = .Percentage_Of_Parent, value = 1.0},
		{kind = .Percentage_Of_Parent, value = 1.0},
	}

	ui.container(
		ctx,
		"main_container",
		ui.Config_Options {
			layout = {sizing = {&main_container_sizing.x, &main_container_sizing.y}},
		},
		&app_state.data,
		proc(ctx: ^ui.Context, data: ^Data) {

			counter_container_padding := ui.Padding{10, 10, 10, 10}
			counter_container_child_gap: f32 = 10
			counter_container_sizing := [2]ui.Sizing {
				{kind = .Fixed, value = 200},
				{kind = .Fixed, value = 70},
			}

			ui.container(
				ctx,
				"counter_container",
				ui.Config_Options {
					layout = {
						sizing = {&counter_container_sizing.x, &counter_container_sizing.y},
						padding = &counter_container_padding,
						child_gap = &counter_container_child_gap,
					},
				},
				data,
				proc(ctx: ^ui.Context, data: ^Data) {

					ui.push_border_fill(
						ctx,
						base.Fill(base.Color{24, 36, 0, 255}),
					); defer ui.pop_border_fill(ctx)

					counter_text_border_fill := base.Fill(base.Color{0, 0, 0, 0})

					strings.write_int(&data.sb, data.counter)
					num_str := strings.to_string(data.sb)
					defer strings.builder_reset(&data.sb)

					ui.text(
						ctx,
						"counter_text",
						num_str,
						ui.Config_Options{border_fill = &counter_text_border_fill},
					)

					ui.push_border_thickness(ctx, 2); defer ui.pop_border_thickness(ctx)

					if ui.button(ctx, "counter_minus_button", "-").clicked {
						data.counter -= 1
					}

					if ui.button(ctx, "counter_plus_button", "+").clicked {
						data.counter += 1
					}
				},
			)
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

	window, window_ok := backend.init_and_create_window("ImGUI", WINDOW_WIDTH, WINDOW_HEIGHT)
	assert(window_ok)

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

	string_buffer := [16]u8{}

	app_state := App_State {
		window = window,
		window_size = {WINDOW_WIDTH, WINDOW_HEIGHT},
		ctx = ctx,
		backend_ctx = backend_ctx,
		running = true,
		data = Data{counter = 0, sb = strings.builder_from_bytes(string_buffer[:])},
	}
	defer deinit_app_state(&app_state)

	io := &app_state.backend_ctx.io
	for app_state.running {
		backend.time(io)
		app_state.ctx.dt = io.frame_time.dt
		process_events(&app_state)
		backend.process_events(&app_state.backend_ctx, &app_state.ctx)

		backend.render_begin(&app_state.backend_ctx.render_ctx)

		build_ui(&app_state)

		backend.render_end(&app_state.backend_ctx.render_ctx, app_state.ctx.command_queue[:])

		sdl.Delay(10)
	}
}
