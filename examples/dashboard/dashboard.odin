package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"

import "../../app"
import "../../base"
import "../../diagnostics"
import "../../ui"


// Theme struct for switchable color schemes
Theme :: struct {
	bg_main:        base.Color,
	bg_sidebar:     base.Color,
	bg_card:        base.Color,
	bg_input:       base.Color,
	accent_primary: base.Color,
	accent_success: base.Color,
	accent_warning: base.Color,
	accent_danger:  base.Color,
	text_primary:   base.Color,
	text_secondary: base.Color,
	text_muted:     base.Color,
	border:         base.Color,
}

// Dark theme
DARK_THEME :: Theme {
	bg_main        = {18, 18, 24, 255},
	bg_sidebar     = {24, 26, 33, 255},
	bg_card        = {32, 34, 42, 255},
	bg_input       = {42, 44, 54, 255},
	accent_primary = {99, 102, 241, 255},
	accent_success = {34, 197, 94, 255},
	accent_warning = {234, 179, 8, 255},
	accent_danger  = {239, 68, 68, 255},
	text_primary   = {243, 244, 246, 255},
	text_secondary = {156, 163, 175, 255},
	text_muted     = {107, 114, 128, 255},
	border         = {55, 58, 70, 255},
}

// Light theme
LIGHT_THEME :: Theme {
	bg_main        = {245, 245, 250, 255},
	bg_sidebar     = {255, 255, 255, 255},
	bg_card        = {255, 255, 255, 255},
	bg_input       = {240, 240, 245, 255},
	accent_primary = {79, 70, 229, 255},
	accent_success = {22, 163, 74, 255},
	accent_warning = {202, 138, 4, 255},
	accent_danger  = {220, 38, 38, 255},
	text_primary   = {17, 24, 39, 255},
	text_secondary = {75, 85, 99, 255},
	text_muted     = {107, 114, 128, 255},
	border         = {209, 213, 219, 255},
}

get_theme :: proc(dark_mode: bool) -> Theme {
	return DARK_THEME if dark_mode else LIGHT_THEME
}

Data :: struct {
	// Form state
	username_buf:    []u8,
	username_len:    int,
	email_buf:       []u8,
	email_len:       int,
	search_buf:      []u8,
	search_len:      int,
	// Settings
	notifications:   bool,
	dark_mode:       bool,
	auto_save:       bool,
	// Sliders
	volume:          f32,
	brightness:      f32,
	// Stats
	active_users:    int,
	total_orders:    int,
	revenue:         f32,
	conversion_rate: f32,
	// Navigation
	selected_nav:    int,
}

build_ui :: proc(ctx: ^ui.Context, data: ^Data) {
	theme := get_theme(data.dark_mode)

	if ui.begin(ctx) {
		// Main layout container (ui.begin already creates implicit root)
		if ui.begin_container(
			ctx,
			"layout",
			ui.Style {
				sizing_x = ui.sizing_percent(1.0),
				sizing_y = ui.sizing_percent(1.0),
				background_fill = base.fill(theme.bg_main),
				capability_flags = ui.Capability_Flags{.Background},
				layout_direction = .Left_To_Right,
			},
		) {
			// ==========================================
			// SIDEBAR (1 part) - demonstrates 1:4 ratio
			// ==========================================
			build_sidebar(ctx, data, theme)

			// ==========================================
			// MAIN CONTENT (4 parts)
			// ==========================================
			build_main_content(ctx, data, theme)

			ui.end_container(ctx)
		}

		ui.end(ctx)
	}
}

build_sidebar :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	if ui.begin_container(
		ctx,
		"sidebar",
		ui.Style {
			sizing_x = ui.sizing_grow_weighted(1, min = 180, max = 250),
			sizing_y = ui.sizing_grow(),
			background_fill = base.fill(theme.bg_sidebar),
			capability_flags = ui.Capability_Flags{.Background},
			layout_direction = .Top_To_Bottom,
			padding = ui.padding_all(16),
			child_gap = 8,
		},
	) {
		// Logo/Title
		ui.text(
			ctx,
			"logo",
			"Dashboard",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				text_fill = base.fill(theme.text_primary),
				text_alignment_x = .Center,
			},
		)

		ui.container(ctx, "logo_spacer", ui.Style{sizing_y = ui.sizing_fixed(24)})

		// Navigation items
		fa := ctx.frame_allocator
		nav_items := []string{"Overview", "Analytics", "Users", "Settings", "Help"}
		for item, i in nav_items {
			is_selected := data.selected_nav == i
			bg_color := theme.accent_primary if is_selected else theme.bg_sidebar
			text_color := theme.text_primary if is_selected else theme.text_secondary

			comm := ui.button(
				ctx,
				fmt.aprintf("nav_%d", i, allocator = fa),
				item,
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(40),
					background_fill = base.fill(bg_color),
					text_fill = base.fill(text_color),
					border_radius = ui.border_radius_all(6),
					text_alignment_x = .Left,
					padding = ui.padding_xy(0, 12),
				},
			)
			if comm.clicked {
				data.selected_nav = i
			}
		}

		// Spacer pushes user section to bottom
		ui.spacer(ctx)

		// User section at bottom
		if ui.begin_container(
			ctx,
			"user_section",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fit(),
				layout_direction = .Left_To_Right,
				child_gap = 12,
				padding = ui.padding_all(12),
				background_fill = base.fill(theme.bg_card),
				capability_flags = ui.Capability_Flags{.Background},
				border_radius = ui.border_radius_all(8),
				alignment_y = .Center,
			},
		) {
			// Avatar placeholder
			ui.container(
				ctx,
				"avatar",
				ui.Style {
					sizing_x = ui.sizing_fixed(36),
					sizing_y = ui.sizing_fixed(36),
					background_fill = base.fill(theme.accent_primary),
					capability_flags = ui.Capability_Flags{.Background},
					border_radius = ui.border_radius_all(18),
				},
			)
			// User info - grows to fill remaining space
			if ui.begin_container(
				ctx,
				"user_info",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fit(),
					layout_direction = .Top_To_Bottom,
					child_gap = 2,
				},
			) {
				ui.text(
					ctx,
					"user_name",
					"John Doe",
					ui.Style{text_fill = base.fill(theme.text_primary)},
				)
				ui.text(
					ctx,
					"user_role",
					"Admin",
					ui.Style{text_fill = base.fill(theme.text_muted)},
				)
				ui.end_container(ctx)
			}
			ui.end_container(ctx)
		}

		ui.end_container(ctx)
	}
}

build_main_content :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	if ui.begin_container(
		ctx,
		"main_content",
		ui.Style {
			sizing_x = ui.sizing_grow_weighted(4),
			sizing_y = ui.sizing_grow(),
			layout_direction = .Top_To_Bottom,
			padding = ui.padding_all(24),
			child_gap = 24,
		},
	) {
		// Header with search
		build_header(ctx, data, theme)

		// Stats row - 4 equal cards
		build_stats_row(ctx, data, theme)

		// Main panels - 2:1 ratio
		if ui.begin_container(
			ctx,
			"panels_row",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_grow(),
				layout_direction = .Left_To_Right,
				child_gap = 24,
			},
		) {
			// Left panel (2 parts) - Form
			build_form_panel(ctx, data, theme)

			// Right panel (1 part) - Settings
			build_settings_panel(ctx, data, theme)

			ui.end_container(ctx)
		}

		ui.end_container(ctx)
	}
}

build_header :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	if ui.begin_container(
		ctx,
		"header",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Left_To_Right,
			child_gap = 16,
			alignment_y = .Center,
		},
	) {
		// Title
		ui.text(
			ctx,
			"page_title",
			"Welcome back, John!",
			ui.Style{sizing_x = ui.sizing_fit(), text_fill = base.fill(theme.text_primary)},
		)

		// Spacer - push search and buttons to right
		ui.spacer(ctx)

		// Search bar - constrained width with min/max
		ui.text_input(
			ctx,
			"search",
			data.search_buf,
			&data.search_len,
			ui.Style {
				sizing_x = ui.sizing_grow(min = 200, max = 300),
				sizing_y = ui.sizing_fixed(40),
				background_fill = base.fill(theme.bg_input),
				border_radius = ui.border_radius_all(8),
				text_fill = base.fill(theme.text_primary),
			},
		)

		// Action buttons
		ui.button(
			ctx,
			"btn_notifications",
			"Alerts",
			ui.Style {
				sizing_x = ui.sizing_fit(),
				sizing_y = ui.sizing_fixed(40),
				background_fill = base.fill(theme.bg_card),
				text_fill = base.fill(theme.text_primary),
				border_radius = ui.border_radius_all(8),
			},
		)
		ui.button(
			ctx,
			"btn_new",
			"+ New",
			ui.Style {
				sizing_x = ui.sizing_fit(),
				sizing_y = ui.sizing_fixed(40),
				background_fill = base.fill(theme.accent_primary),
				border_radius = ui.border_radius_all(8),
			},
		)

		ui.end_container(ctx)
	}
}

build_stats_row :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	// ==========================================
	// EQUAL DISTRIBUTION - 4 cards with factor=1
	// Each gets exactly 25% of available space
	// ==========================================
	if ui.begin_container(
		ctx,
		"stats_row",
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Left_To_Right,
			child_gap = 16,
		},
	) {
		fa := ctx.frame_allocator
		stat_card(
			ctx,
			"stat_users",
			"Active Users",
			fmt.aprintf("%d", data.active_users, allocator = fa),
			theme.accent_primary,
			theme,
		)
		stat_card(
			ctx,
			"stat_orders",
			"Total Orders",
			fmt.aprintf("%d", data.total_orders, allocator = fa),
			theme.accent_success,
			theme,
		)
		stat_card(
			ctx,
			"stat_revenue",
			"Revenue",
			fmt.aprintf("$%.0f", data.revenue, allocator = fa),
			theme.accent_warning,
			theme,
		)
		stat_card(
			ctx,
			"stat_conversion",
			"Conversion",
			fmt.aprintf("%.1f%%", data.conversion_rate, allocator = fa),
			theme.accent_danger,
			theme,
		)

		ui.end_container(ctx)
	}
}

stat_card :: proc(
	ctx: ^ui.Context,
	id: string,
	label: string,
	value: string,
	accent: base.Color,
	theme: Theme,
) {
	if ui.begin_container(
	ctx,
	id,
	ui.Style {
		// Equal grow factor - all cards same size
		sizing_x         = ui.sizing_grow(),
		sizing_y         = ui.sizing_fit(),
		layout_direction = .Top_To_Bottom,
		padding          = ui.padding_all(20),
		child_gap        = 8,
		background_fill  = base.fill(theme.bg_card),
		capability_flags = ui.Capability_Flags{.Background},
		border_radius    = ui.border_radius_all(12),
		border           = ui.border_all(1),
		border_fill      = base.fill(theme.border),
	},
	) {
		fa := ctx.frame_allocator
		// Accent bar
		ui.container(
			ctx,
			fmt.aprintf("%s_accent", id, allocator = fa),
			ui.Style {
				sizing_x = ui.sizing_fixed(40),
				sizing_y = ui.sizing_fixed(4),
				background_fill = base.fill(accent),
				capability_flags = ui.Capability_Flags{.Background},
				border_radius = ui.border_radius_all(2),
			},
		)
		ui.text(
			ctx,
			fmt.aprintf("%s_label", id, allocator = fa),
			label,
			ui.Style{text_fill = base.fill(theme.text_secondary)},
		)
		ui.text(
			ctx,
			fmt.aprintf("%s_value", id, allocator = fa),
			value,
			ui.Style{text_fill = base.fill(theme.text_primary)},
		)

		ui.end_container(ctx)
	}
}

build_form_panel :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	// ==========================================
	// 2:1 RATIO - Form panel gets 2 parts
	// ==========================================
	if ui.begin_container(
		ctx,
		"form_panel",
		ui.Style {
			sizing_x = ui.sizing_grow_weighted(2),
			sizing_y = ui.sizing_grow(),
			layout_direction = .Top_To_Bottom,
			padding = ui.padding_all(24),
			child_gap = 20,
			background_fill = base.fill(theme.bg_card),
			capability_flags = ui.Capability_Flags{.Background},
			border_radius = ui.border_radius_all(12),
		},
	) {
		// Panel header
		ui.text(
			ctx,
			"form_title",
			"User Profile",
			ui.Style{text_fill = base.fill(theme.text_primary)},
		)

		// Form fields
		form_field(ctx, "username_field", "Username", data.username_buf, &data.username_len, theme)
		form_field(ctx, "email_field", "Email", data.email_buf, &data.email_len, theme)

		// Sliders section
		ui.text(
			ctx,
			"sliders_title",
			"Preferences",
			ui.Style{text_fill = base.fill(theme.text_secondary)},
		)

		slider_field(ctx, "volume_field", "Volume", &data.volume, theme)
		slider_field(ctx, "brightness_field", "Brightness", &data.brightness, theme)


		// Spacer
		ui.spacer(ctx)

		// Action buttons row - demonstrates equal distribution
		if ui.begin_container(
			ctx,
			"form_actions",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fit(),
				layout_direction = .Left_To_Right,
				child_gap = 12,
			},
		) {
			// Cancel and Save buttons - equal width (both factor=1)
			ui.button(
				ctx,
				"btn_cancel",
				"Cancel",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(44),
					background_fill = base.fill(theme.bg_input),
					text_fill = base.fill(theme.text_primary),
					border_radius = ui.border_radius_all(8),
				},
			)
			ui.button(
				ctx,
				"btn_save",
				"Save Changes",
				ui.Style {
					sizing_x = ui.sizing_grow(),
					sizing_y = ui.sizing_fixed(44),
					background_fill = base.fill(theme.accent_primary),
					border_radius = ui.border_radius_all(8),
				},
			)

			ui.end_container(ctx)
		}

		ui.end_container(ctx)
	}
}

form_field :: proc(
	ctx: ^ui.Context,
	id: string,
	label: string,
	buf: []u8,
	len: ^int,
	theme: Theme,
) {
	if ui.begin_container(
		ctx,
		id,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Top_To_Bottom,
			child_gap = 8,
		},
	) {
		fa := ctx.frame_allocator
		ui.text(
			ctx,
			fmt.aprintf("%s_label", id, allocator = fa),
			label,
			ui.Style{text_fill = base.fill(theme.text_secondary)},
		)
		ui.text_input(
			ctx,
			fmt.aprintf("%s_input", id, allocator = fa),
			buf,
			len,
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fixed(44),
				background_fill = base.fill(theme.bg_input),
				border_radius = ui.border_radius_all(8),
				border = ui.border_all(1),
				border_fill = base.fill(theme.border),
				text_fill = base.fill(theme.text_primary),
			},
		)

		ui.end_container(ctx)
	}
}

slider_field :: proc(ctx: ^ui.Context, id: string, label: string, value: ^f32, theme: Theme) {
	if ui.begin_container(
		ctx,
		id,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Left_To_Right,
			child_gap = 16,
			alignment_y = .Center,
		},
	) {
		fa := ctx.frame_allocator
		// Label - grows with weight 1
		ui.text(
			ctx,
			fmt.aprintf("%s_label", id, allocator = fa),
			label,
			ui.Style {
				sizing_x = ui.sizing_grow_weighted(1),
				text_fill = base.fill(theme.text_secondary),
			},
		)
		// Slider - grows with weight 3
		ui.slider(
			ctx,
			fmt.aprintf("%s_slider", id, allocator = fa),
			value,
			0.0,
			1.0,
			style = ui.Style {
				sizing_x = ui.sizing_grow_weighted(3),
				sizing_y = ui.sizing_fixed(8),
				background_fill = base.fill(theme.bg_input),
				border_radius = ui.border_radius_all(4),
			},
		)
		// Value display - grow with weight 0.5
		ui.text(
			ctx,
			fmt.aprintf("%s_value", id, allocator = fa),
			fmt.aprintf("%.0f%%", value^ * 100, allocator = fa),
			ui.Style {
				sizing_x = ui.sizing_grow_weighted(0.5),
				text_fill = base.fill(theme.text_muted),
				text_alignment_x = .Right,
			},
		)

		ui.end_container(ctx)
	}
}

build_settings_panel :: proc(ctx: ^ui.Context, data: ^Data, theme: Theme) {
	// ==========================================
	// 2:1 RATIO - Settings panel gets 1 part
	// Also demonstrates min constraint
	// ==========================================
	if ui.begin_container(
		ctx,
		"settings_panel",
		ui.Style {
			sizing_x = ui.sizing_grow_weighted(1, min = 250),
			sizing_y = ui.sizing_grow(),
			layout_direction = .Top_To_Bottom,
			padding = ui.padding_all(24),
			child_gap = 16,
			background_fill = base.fill(theme.bg_card),
			capability_flags = ui.Capability_Flags{.Background},
			border_radius = ui.border_radius_all(12),
		},
	) {
		ui.text(
			ctx,
			"settings_title",
			"Quick Settings",
			ui.Style{text_fill = base.fill(theme.text_primary)},
		)

		// Toggle settings
		toggle_setting(ctx, "toggle_notifications", "Notifications", &data.notifications, theme)
		toggle_setting(ctx, "toggle_dark_mode", "Dark Mode", &data.dark_mode, theme)
		toggle_setting(ctx, "toggle_auto_save", "Auto Save", &data.auto_save, theme)

		ui.spacer(ctx)

		// Status indicators - demonstrates 1:1:1 equal distribution
		ui.text(
			ctx,
			"status_title",
			"System Status",
			ui.Style{text_fill = base.fill(theme.text_secondary)},
		)

		if ui.begin_container(
			ctx,
			"status_row",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fit(),
				layout_direction = .Left_To_Right,
				child_gap = 8,
			},
		) {
			status_indicator(ctx, "status_api", "API", theme.accent_success, theme)
			status_indicator(ctx, "status_db", "DB", theme.accent_success, theme)
			status_indicator(ctx, "status_cdn", "CDN", theme.accent_warning, theme)

			ui.end_container(ctx)
		}

		ui.spacer(ctx)

		// Danger zone
		ui.text(
			ctx,
			"danger_title",
			"Danger Zone",
			ui.Style{text_fill = base.fill(theme.accent_danger)},
		)
		ui.button(
			ctx,
			"btn_reset",
			"Reset All Settings",
			ui.Style {
				sizing_x = ui.sizing_grow(),
				sizing_y = ui.sizing_fixed(40),
				background_fill = base.fill(theme.accent_danger),
				border_radius = ui.border_radius_all(8),
			},
		)

		ui.end_container(ctx)
	}
}

toggle_setting :: proc(ctx: ^ui.Context, id: string, label: string, value: ^bool, theme: Theme) {
	if ui.begin_container(
		ctx,
		id,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Left_To_Right,
			child_gap = 12,
			alignment_y = .Center,
			padding = ui.padding_xy(12, 0),
		},
	) {
		fa := ctx.frame_allocator
		// Label takes remaining space
		ui.text(
			ctx,
			fmt.aprintf("%s_label", id, allocator = fa),
			label,
			ui.Style{sizing_x = ui.sizing_grow(), text_fill = base.fill(theme.text_primary)},
		)
		checkbox_color := theme.accent_success if value^ else theme.bg_input
		ui.checkbox(
			ctx,
			fmt.aprintf("%s_checkbox", id, allocator = fa),
			value,
			ui.Shape_Data{ui.Shape_Kind.Checkmark, base.fill_color(255, 255, 255), 2.0},
			ui.Style {
				sizing_x = ui.sizing_fixed(24),
				sizing_y = ui.sizing_fixed(24),
				background_fill = base.fill(checkbox_color),
				border_radius = ui.border_radius_all(4),
			},
		)

		ui.end_container(ctx)
	}
}

status_indicator :: proc(
	ctx: ^ui.Context,
	id: string,
	label: string,
	color: base.Color,
	theme: Theme,
) {
	// Equal grow factor - all indicators same width
	if ui.begin_container(
		ctx,
		id,
		ui.Style {
			sizing_x = ui.sizing_grow(),
			sizing_y = ui.sizing_fit(),
			layout_direction = .Top_To_Bottom,
			child_gap = 4,
			padding = ui.padding_all(8),
			background_fill = base.fill(theme.bg_input),
			capability_flags = ui.Capability_Flags{.Background},
			border_radius = ui.border_radius_all(6),
			alignment_x = .Center,
		},
	) {
		fa := ctx.frame_allocator
		// Status dot
		ui.container(
			ctx,
			fmt.aprintf("%s_dot", id, allocator = fa),
			ui.Style {
				sizing_x = ui.sizing_fixed(8),
				sizing_y = ui.sizing_fixed(8),
				background_fill = base.fill(color),
				capability_flags = ui.Capability_Flags{.Background},
				border_radius = ui.border_radius_all(4),
			},
		)
		ui.text(
			ctx,
			fmt.aprintf("%s_label", id, allocator = fa),
			label,
			ui.Style{text_fill = base.fill(theme.text_muted)},
		)

		ui.end_container(ctx)
	}
}

update_and_draw :: proc(ctx: ^ui.Context, data: ^Data) {
	build_ui(ctx, data)
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
		title     = "Dashboard Demo - Weighted Grow Factors",
		width     = 1200,
		height    = 800,
		font_path = "",
		font_id   = 0,
		font_size = 24,
		memory    = app_memory,
	}

	my_app, my_app_ok := app.init(config)
	if !my_app_ok {
		log.error("Failed to initialize application")
		return
	}
	defer app.deinit(my_app)

	// Initialize data with buffers and default values
	username_buf := make([]u8, 128)
	defer delete(username_buf)
	email_buf := make([]u8, 128)
	defer delete(email_buf)
	search_buf := make([]u8, 128)
	defer delete(search_buf)

	data := Data {
		username_buf    = username_buf,
		username_len    = 0,
		email_buf       = email_buf,
		email_len       = 0,
		search_buf      = search_buf,
		search_len      = 0,
		notifications   = true,
		dark_mode       = true,
		auto_save       = false,
		volume          = 0.75,
		brightness      = 0.5,
		active_users    = 1234,
		total_orders    = 5678,
		revenue         = 12345,
		conversion_rate = 3.2,
		selected_nav    = 0,
	}

	app.run(my_app, &data, update_and_draw)
}
