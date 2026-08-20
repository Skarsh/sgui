package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "../../app"
import "../../backend"
import "../../base"
import "../../diagnostics"
import "../../ui"

Task :: struct {
	text:      string,
	completed: bool,
}

Data :: struct {
	allocator:        mem.Allocator,
	tasks:            [dynamic]Task,
	new_task_buf:     []u8,
	new_task_buf_len: int,
}

// --- Style Palette: "Warm Retro" ---
WINDOW_BG :: base.Color{40, 40, 40, 255}
PANEL_BG :: base.Color{60, 56, 54, 255}
ROW_BG :: base.Color{80, 73, 69, 255}
ITEM_BG :: base.Color{102, 92, 84, 255}
ITEM_HOVER_BG :: base.Color{124, 111, 100, 255}
TEXT_COLOR :: base.Color{235, 219, 178, 255}
COMPLETED_TEXT_COLOR :: base.Color{146, 131, 116, 255}
DELETE_BUTTON_COLOR :: base.Color{204, 36, 29, 255}
ADD_BUTTON_COLOR :: base.Color{152, 151, 26, 255}
CHECKBOX_EMPTY_BG :: base.Color{56, 50, 48, 255}
CHECKBOX_DONE_BG :: base.Color{184, 187, 38, 255}

add_new_task :: proc(data: ^Data, text: string) {
	new_task_text, alloc_err := strings.clone(text, data.allocator)
	assert(alloc_err == .None)
	append(&data.tasks, Task{text = new_task_text, completed = false})
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	ui.begin(ctx)
	// --- Global Style Scope ---
	ui.push_style(
		ctx,
		ui.Style {
			background_fill = WINDOW_BG,
			capability_flags = ui.Capability_Flags{.Background},
			text_fill = TEXT_COLOR,
		},
	)
	defer ui.pop_style(ctx)

	// --- Main Panel (centered) ---
	ui.begin_container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			alignment_x = base.Alignment_X.Center,
			alignment_y = base.Alignment_Y.Center,
		},
		name = "main_panel",
	)

	// --- Inner content panel ---
	ui.begin_container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_percent(1.0),
			sizing_y = ui.sizing_percent(1.0),
			padding = ui.padding_all(25),
			border_radius = ui.border_radius_all(10),
			layout_direction = ui.Layout_Direction.Top_To_Bottom,
			child_gap = 15,
			background_fill = PANEL_BG,
		},
		name = "panel",
	)
	// --- Title ---
	ui.text(
		ctx,
		"Odin To-Do List",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_grow(max = 50),
			text_alignment_x = base.Alignment_X.Center,
			background_fill = base.fill_color(0, 0, 0, 0),
		},
		name = "title",
	)

	// -- Task List Wrapper
	ui.begin_container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(max = 350),
			layout_direction = ui.Layout_Direction.Left_To_Right,
			child_gap = 5,
			border = ui.Border{top = 8, right = 7, bottom = 10, left = 5},
			padding = ui.padding_all(5),
			background_fill = base.fill_color(50, 50, 55),
			border_fill = base.fill_color(100, 69, 69),
		},
		name = "task_list_wrapper",
	)

	// --- Task List ---
	task_list_name := "task_list"
	task_list_comm := ui.begin_container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(max = 300),
			layout_direction = ui.Layout_Direction.Top_To_Bottom,
			child_gap = 8,
			padding = ui.padding_all(10),
			capability_flags = ui.Capability_Flags{.Scrollable_Y},
			clip = ui.Clip_Config{clip_axes = {true, true}},
		},
		name = task_list_name,
	)

	for &task, i in data.tasks {

		// --- Task Row ---
		ui.push_style(ctx, ui.Style{background_fill = ROW_BG})
		defer ui.pop_style(ctx)

		ui.push_id(ctx, i)
		ui.begin_container(
			ctx,
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fit(),
				layout_direction = ui.Layout_Direction.Left_To_Right,
				alignment_y = base.Alignment_Y.Center,
				child_gap = 10,
				padding = ui.padding_all(5),
			},
			name = fmt.tprintf("task_row_%d", i),
		)
		ui.pop_id(ctx)

		// --- Checkbox Button ---
		current_checkbox_color := CHECKBOX_EMPTY_BG
		if task.completed {
			current_checkbox_color = CHECKBOX_DONE_BG
		}

		ui.push_id(ctx, i)
		ui.checkbox(
			ctx,
			&task.completed,
			ui.Shape_Data{ui.Shape_Kind.Checkmark, base.fill_color(255, 255, 255), 2.0},
			ui.Style {
				sizing_x = ui.sizing_fixed(36),
				sizing_y = ui.sizing_fixed(36),
				background_fill = current_checkbox_color,
			},
			name = fmt.tprintf("tasks_checkbox_%d", i),
		)
		ui.pop_id(ctx)

		// --- Task Text ---
		task_name := fmt.tprintf("task_text_%d", i)

		task_text_color := TEXT_COLOR
		if task.completed {
			task_text_color = COMPLETED_TEXT_COLOR
		}

		ui.push_id(ctx, i)
		ui.text(
			ctx,
			task.text,
			ui.Style {
				sizing_x = ui.sizing_grow(),
				alignment_y = base.Alignment_Y.Center,
				text_alignment_y = base.Alignment_Y.Center,
				text_fill = task_text_color,
			},
			name = task_name,
		)
		ui.pop_id(ctx)

		// --- Delete Button ---
		delete_button_name := fmt.tprintf("task_delete_button_%d", i)
		ui.push_id(ctx, i)
		delete_comm := ui.button(
			ctx,
			"Delete",
			ui.Style {
				sizing_x = ui.sizing_fit(),
				sizing_y = ui.sizing_fit(),
				border_radius = ui.border_radius_all(3.0),
				background_fill = DELETE_BUTTON_COLOR,
			},
			name = delete_button_name,
		)
		ui.pop_id(ctx)
		if delete_comm.clicked {
			ordered_remove(&data.tasks, i)
		}

		ui.end_container(ctx)

	}

	ui.end_container(ctx)


	ui.scrollbar(
		ctx,
		task_list_comm.element,
		.Y,
		ui.Style {
			sizing_x = ui.sizing_fixed(12),
			sizing_y = ui.sizing_grow(),
			border_radius = ui.border_radius_all(6.0),
			background_fill = base.fill_color(0, 0, 0, 0),
			position_mode = .Flow,
		},
		name = "task_list_scrollbar",
	)

	ui.end_container(ctx)


	ui.spacer(ctx, style = ui.Style{background_fill = base.fill_color(0, 0, 0, 0)})

	// --- Add Task Panel ---
	input_comm, add_button_comm: ui.Comm
	ui.begin_container(
		ctx,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = ui.Layout_Direction.Left_To_Right,
			child_gap = 10,
		},
		name = "add_task_panel",
	)
	// --- Text Input field ---
	input_comm = ui.text_input(
		ctx,
		data.new_task_buf,
		style = ui.Style{background_fill = ITEM_BG},
		name = "new_task_input",
	)

	// --- Add Button ---
	add_button_comm = ui.button(
		ctx,
		"Add",
		ui.Style{background_fill = ADD_BUTTON_COLOR},
		name = "add_task_button",
	)

	if add_button_comm.clicked {
		add_new_task(data, input_comm.text)
	}

	ui.end_container(ctx)

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
		title = "To-Do List App",
		window_size = {600, 800},
		font_configs = {
			base.Font_Config{"data/fonts/JetBrains_Mono/JetBrainsMono-Regular.ttf", 24, nil},
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

	// --- Initialize Application Data ---
	// Re-using the arena that was used for the app memory here.
	new_task_buf := make([]u8, 256, arena_allocator)
	tasks := make([dynamic]Task, arena_allocator)
	append(&tasks, Task{text = "Learn Odin", completed = true})
	append(&tasks, Task{text = "Build a UI library", completed = true})
	append(&tasks, Task{text = "Create a to-do app", completed = true})
	append(&tasks, Task{text = "Make it scrollable", completed = false})
	append(&tasks, Task{text = "Style it well", completed = false})
	append(&tasks, Task{text = "Task to make it overflow", completed = false})
	append(&tasks, Task{text = "Another task to make it overflow", completed = false})
	append(
		&tasks,
		Task{text = "One more task to test how this affects the scrollbar", completed = false},
	)

	my_data := Data {
		allocator        = arena_allocator,
		tasks            = tasks,
		new_task_buf     = new_task_buf,
		new_task_buf_len = 0,
	}

	app.run(my_app, &my_data, update_and_draw)
}
