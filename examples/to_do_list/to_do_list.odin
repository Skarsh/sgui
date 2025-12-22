package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

import "../../app"
import "../../base"
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

// --- Style Palette: "Modern Dark" ---
//WINDOW_BG :: base.Color{24, 24, 27, 255}
//PANEL_BG :: base.Color{39, 39, 42, 255}
//ROW_BG :: base.Color{63, 63, 70, 255}
//ITEM_BG :: base.Color{82, 82, 91, 255}
//ITEM_HOVER_BG :: base.Color{113, 113, 122, 255}
//TEXT_COLOR :: base.Color{244, 244, 245, 255}
//COMPLETED_TEXT_COLOR :: base.Color{113, 113, 122, 255}
//DELETE_BUTTON_COLOR :: base.Color{225, 29, 72, 255}
//ADD_BUTTON_COLOR :: base.Color{79, 70, 229, 255}
//CHECKBOX_EMPTY_BG :: base.Color{45, 45, 48, 255}
//CHECKBOX_DONE_BG :: base.Color{34, 197, 94, 255}

// --- Style Palette: "Nordic Frost" ---
//WINDOW_BG :: base.Color{46, 52, 64, 255}
//PANEL_BG :: base.Color{59, 66, 82, 255}
//ROW_BG :: base.Color{67, 76, 94, 255}
//ITEM_BG :: base.Color{76, 86, 106, 255}
//ITEM_HOVER_BG :: base.Color{129, 161, 193, 255}
//TEXT_COLOR :: base.Color{236, 239, 244, 255}
//COMPLETED_TEXT_COLOR :: base.Color{148, 156, 172, 255}
//DELETE_BUTTON_COLOR :: base.Color{191, 97, 106, 255}
//ADD_BUTTON_COLOR :: base.Color{136, 192, 208, 255}
//CHECKBOX_EMPTY_BG :: base.Color{55, 62, 75, 255}
//CHECKBOX_DONE_BG :: base.Color{163, 190, 140, 255}

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


add_new_task :: proc(data: ^Data) {
	if data.new_task_buf_len == 0 {
		return
	}

	new_task_text, alloc_err := strings.clone_from_bytes(
		data.new_task_buf[0:data.new_task_buf_len],
		data.allocator,
	)

	assert(alloc_err == .None)

	append(&data.tasks, Task{text = new_task_text, completed = false})
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	if ui.begin(ctx) {
		// --- Global Style Scope ---
		ui.push_background_fill(ctx, base.Fill(WINDOW_BG)); defer ui.pop_background_fill(ctx)
		ui.push_capability_flags(
			ctx,
			ui.Capability_Flags{.Background},
		); defer ui.pop_capability_flags(ctx)
		ui.push_text_fill(ctx, base.Fill(TEXT_COLOR)); defer ui.pop_text_fill(ctx)

		// --- Main Panel (centered) ---
		main_panel_sizing := [2]ui.Sizing {
			{kind = .Percentage_Of_Parent, value = 1.0},
			{kind = .Percentage_Of_Parent, value = 1.0},
		}
		main_panel_align_x := ui.Alignment_X.Center
		main_panel_align_y := ui.Alignment_Y.Center

		if ui.begin_container(
			ctx,
			"main_panel",
			ui.Config_Options {
				layout = {
					sizing = {&main_panel_sizing.x, &main_panel_sizing.y},
					alignment_x = &main_panel_align_x,
					alignment_y = &main_panel_align_y,
				},
			},
		) {

			// --- Inner content panel ---
			panel_sizing := [2]ui.Sizing {
				{kind = .Percentage_Of_Parent, value = 1.0},
				{kind = .Percentage_Of_Parent, value = 1.0},
			}
			panel_padding := ui.Padding{25, 25, 25, 25}
			panel_radius: f32 = 10
			panel_layout_dir := ui.Layout_Direction.Top_To_Bottom
			panel_child_gap: f32 = 15
			panel_bg := base.Fill(PANEL_BG)

			if ui.begin_container(
				ctx,
				"panel",
				ui.Config_Options {
					layout = {
						sizing = {&panel_sizing.x, &panel_sizing.y},
						layout_direction = &panel_layout_dir,
						padding = &panel_padding,
						child_gap = &panel_child_gap,
						corner_radius = &panel_radius,
					},
					background_fill = &panel_bg,
				},
			) {
				// --- Title ---
				title_text_align_x := ui.Alignment_X.Center
				title_sizing := [2]ui.Sizing{{kind = .Grow}, {kind = .Grow, max_value = 50}}
				title_bg_fill := base.Fill(base.Color{0, 0, 0, 0})
				ui.text(
					ctx,
					"title",
					"Odin To-Do List",
					ui.Config_Options {
						layout = {
							sizing = {&title_sizing.x, &title_sizing.y},
							text_alignment_x = &title_text_align_x,
						},
						background_fill = &title_bg_fill,
					},
				)

				// --- Task List ---
				task_list_sizing := [2]ui.Sizing{{kind = .Grow}, {kind = .Fit, max_value = 600}}
				task_list_layout_dir := ui.Layout_Direction.Top_To_Bottom
				task_list_child_gap: f32 = 8
				task_list_padding: ui.Padding = {10, 10, 10, 10}
				task_list_caps := ui.Capability_Flags{.Scrollable}
				task_list_clip: ui.Clip_Config = {
					clip_axes = {true, true},
				}
				if ui.begin_container(
					ctx,
					"task_list",
					ui.Config_Options {
						layout = {
							sizing = {&task_list_sizing.x, &task_list_sizing.y},
							layout_direction = &task_list_layout_dir,
							child_gap = &task_list_child_gap,
							padding = &task_list_padding,
						},
						clip = &task_list_clip,
						capability_flags = &task_list_caps,
					},
				) {

					for &task, i in data.tasks {

						// --- Task Row ---
						row_sizing := [2]ui.Sizing{{kind = .Grow}, {kind = .Fit}}
						row_layout_dir := ui.Layout_Direction.Left_To_Right
						row_align_y := ui.Alignment_Y.Center
						row_child_gap: f32 = 10
						row_padding := ui.Padding{5, 5, 5, 5}

						ui.push_background_fill(
							ctx,
							base.Fill(ROW_BG),
						); defer ui.pop_background_fill(ctx)

						if ui.begin_container(
							ctx,
							fmt.tprintf("task_row_%d", i),
							ui.Config_Options {
								layout = {
									sizing = {&row_sizing.x, &row_sizing.y},
									layout_direction = &row_layout_dir,
									alignment_y = &row_align_y,
									child_gap = &row_child_gap,
									padding = &row_padding,
								},
							},
						) {

							// --- Checkbox Button ---
							current_checkbox_color := CHECKBOX_EMPTY_BG
							if task.completed {
								current_checkbox_color = CHECKBOX_DONE_BG
							}

							checkbox_bg_fill := base.Fill(current_checkbox_color)

							ui.checkbox(
								ctx,
								fmt.tprintf("tasks_checkbox_%d", i),
								&task.completed,
								ui.Shape_Data {
									ui.Shape_Kind.Checkmark,
									base.Fill(base.Color{255, 255, 255, 255}),
									2.0,
								},
								ui.Config_Options{background_fill = &checkbox_bg_fill},
							)

							// --- Spacer ---
							ui.spacer(ctx)

							// --- Task Text ---
							alignment_y := ui.Alignment_Y.Center
							text_alignment_y := ui.Alignment_Y.Center
							task_id := fmt.tprintf("task_text_%d", i)

							task_text_color := TEXT_COLOR
							if task.completed {
								task_text_color = COMPLETED_TEXT_COLOR
							}

							task_text_fill := base.Fill(task_text_color)

							ui.text(
								ctx,
								task_id,
								task.text,
								ui.Config_Options {
									layout = {
										alignment_y = &alignment_y,
										text_alignment_y = &text_alignment_y,
									},
									text_fill = &task_text_fill,
								},
							)

							// --- Spacer ---
							ui.spacer(ctx)

							// --- Delete Button ---
							delete_corner_radius: f32 = 3.0
							delete_bg_fill := base.Fill(DELETE_BUTTON_COLOR)
							delete_button_id := fmt.tprintf("task_delete_button_%d", i)
							delete_comm := ui.button(
								ctx,
								delete_button_id,
								"Delete",
								ui.Config_Options {
									layout = {corner_radius = &delete_corner_radius},
									background_fill = &delete_bg_fill,
								},
							)
							if delete_comm.clicked {
								ordered_remove(&data.tasks, i)
							}

							ui.end_container(ctx)
						}
					}

					ui.end_container(ctx)
				}

				spacer_bg_fill := base.Fill(base.Color{0, 0, 0, 0})
				ui.spacer(ctx, opts = ui.Config_Options{background_fill = &spacer_bg_fill})

				// --- Add Task Panel ---
				add_task_panel_sizing := [2]ui.Sizing{{kind = .Grow}, {kind = .Fit}}
				add_task_layout_direction := ui.Layout_Direction.Left_To_Right
				add_task_child_gap: f32 = 10
				input_comm, add_button_comm: ui.Comm
				if ui.begin_container(
					ctx,
					"add_task_panel",
					ui.Config_Options {
						layout = {
							sizing = {&add_task_panel_sizing.x, &add_task_panel_sizing.y},
							layout_direction = &add_task_layout_direction,
							child_gap = &add_task_child_gap,
						},
					},
				) {
					// --- Text Input field ---
					input_bg := base.Fill(ITEM_BG)

					input_comm = ui.text_input(
						ctx,
						"new_task_input",
						data.new_task_buf,
						&data.new_task_buf_len,
						ui.Config_Options{background_fill = &input_bg},
					)

					// --- Add Button ---
					add_button_fill := base.Fill(ADD_BUTTON_COLOR)
					add_button_comm = ui.button(
						ctx,
						"add_task_button",
						"Add",
						ui.Config_Options{background_fill = &add_button_fill},
					)

					if add_button_comm.clicked {
						add_new_task(data)
					}

					ui.end_container(ctx)
				}


				ui.end_container(ctx)
			}

			ui.end_container(ctx)
		}

		ui.end(ctx)
	}
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) {
	build_ui(ctx, data)
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

	config := app.App_Config {
		title     = "To-Do List App",
		width     = 600,
		height    = 800,
		font_path = "",
		font_id   = 0,
		font_size = 24,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize GUI application")
		return
	}
	defer app.deinit(my_app)

	// --- Initialize Application Data ---
	new_task_buf := make([]u8, 256)
	defer delete(new_task_buf)

	arena := virtual.Arena{}
	arena_err := virtual.arena_init_static(&arena, 10 * mem.Kilobyte)
	assert(arena_err == .None)
	arena_allocator := virtual.arena_allocator(&arena)
	defer free_all(arena_allocator)

	tasks := make([dynamic]Task, arena_allocator)
	append(&tasks, Task{text = "Learn Odin", completed = true})
	append(&tasks, Task{text = "Build a UI library", completed = true})
	append(&tasks, Task{text = "Create a to-do app", completed = false})

	my_data := Data {
		allocator        = arena_allocator,
		tasks            = tasks,
		new_task_buf     = new_task_buf,
		new_task_buf_len = 0,
	}

	app.run(my_app, &my_data, update_and_draw)
}
