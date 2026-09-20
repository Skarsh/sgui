package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:time"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import textpkg "../../text"
import "../../ui"

Benchmark_Config :: struct {
	element_count:  int,
	sample_text:    string,
	window_size:    [2]i32,
	font_config:    base.Font_Config,
	text_wrap_mode: textpkg.Text_Wrap_Mode,
}

Benchmark :: struct {
	frame_counter:         int,
	warm_up_frames:        int,
	measured_frames:       int,
	measured_frames_limit: int,
	total_ui_time:         time.Duration,
	config:                Benchmark_Config,
}

print_benchmark :: proc(benchmark: Benchmark) {

	average_ms :=
		time.duration_milliseconds(benchmark.total_ui_time) / f64(benchmark.measured_frames)

	fmt.println("--- Benchmark ---")
	fmt.println("Benchmark ran with config:")
	fmt.println("", benchmark.config)
	fmt.println("Benchmark result:")
	fmt.printfln("Average UI build: %.4f ms/frame\n", average_ms)
}

SAMPLE_TEXT :: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."


build_ui :: proc(ctx: ^ui.Context, benchmark: ^Benchmark) {
	benchmark.frame_counter += 1

	ui.begin(ctx)

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
		ui.Style {
			alignment_x = .Center,
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			padding = ui.padding_all(10),
			child_gap = 40,
			layout_direction = .Top_To_Bottom,
			capability_flags = ui.Capability_Flags{.Scrollable_Y},
		},
		name = "main_container",
	)

	for i in 0 ..< benchmark.config.element_count {
		ui.push_id(ctx, i)
		ui.text(ctx, SAMPLE_TEXT, ui.Style{capability_flags = ui.Capability_Flags{.Selectable}})
		ui.pop_id(ctx)
	}

	ui.end_container(ctx) // main_container


	ui.end(ctx)
}

update_and_draw :: proc(ctx: ^ui.Context, benchmark: ^Benchmark) -> bool {
	if base.is_key_pressed(ctx.interaction.input^, base.Key.Escape) {
		return false
	}

	start := time.tick_now()
	build_ui(ctx, benchmark)
	elapsed := time.tick_since(start)

	if benchmark.frame_counter > benchmark.warm_up_frames &&
	   benchmark.measured_frames < benchmark.measured_frames_limit {
		benchmark.total_ui_time += elapsed
		benchmark.measured_frames += 1

		if benchmark.measured_frames == benchmark.measured_frames_limit {
			print_benchmark(benchmark^)
			return false
		}
	}

	return true
}

main :: proc() {
	// App setup
	arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&arena, 100 * mem.Megabyte)
	assert(arena_err == .None)
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)

	app_memory := app.App_Memory {
		app_arena_mem       = make([]u8, 10 * mem.Megabyte, arena_allocator),
		frame_arena_mem     = make([]u8, 1000 * mem.Kilobyte, arena_allocator),
		draw_command_buffer = make([]ui.Draw_Command, 100 * 1024, arena_allocator),
	}

	config := app.App_Config {
		title = "Counter App",
		window_size = {640, 480},
		font_configs = {
			base.Font_Config{"data/fonts/JetBrains_Mono/JetBrainsMono-Regular.ttf", 48, nil},
		},
		platform_api = {
			get_perf_counter = backend.sdl_get_perf_counter,
			get_perf_freq = backend.sdl_get_perf_freq,
			get_clipboard_text = backend.sdl_get_clipboard_text,
			set_clipboard_text = backend.sdl_set_clipboard_text,
			poll_events = backend.sdl_poll_events,
		},
		window_api = backend.create_sdl_window_api(),
		memory = app_memory,
		allocator = context.allocator,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}
	defer app.deinit(my_app)

	my_data := Benchmark {
		frame_counter = 0,
		warm_up_frames = 100,
		measured_frames = 0,
		measured_frames_limit = 600,
		config = {
			element_count = 10,
			sample_text = SAMPLE_TEXT,
			font_config = config.font_configs[0],
		},
	}
	app.run(my_app, &my_data, update_and_draw)
}
