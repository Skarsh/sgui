package ui

import base "../base"
import "core:math"

// Uniform padding (all sides same)
padding_all :: proc(value: f32) -> Padding {
	return Padding{value, value, value, value}
}

// Symmetric padding (vertical, horizontal)
padding_xy :: proc(vertical, horizontal: f32) -> Padding {
	return Padding{vertical, horizontal, vertical, horizontal}
}

// Individual padding
padding_trbl :: proc(top, right, bottom, left: f32) -> Padding {
	return Padding{top, right, bottom, left}
}

// Uniform margin (all sides same)
margin_all :: proc(value: f32) -> Margin {
	return Margin{value, value, value, value}
}

// Symmetric margin (vertical, horizontal)
margin_xy :: proc(vertical, horizontal: f32) -> Margin {
	return Margin{vertical, horizontal, vertical, horizontal}
}

// Individual margin
margin_trbl :: proc(top, right, bottom, left: f32) -> Margin {
	return Margin{top, right, bottom, left}
}

// Uniform border (all sides same)
border_all :: proc(value: f32) -> Border {
	return Border{value, value, value, value}
}

// Symmetric border (vertical, horizontal)
border_xy :: proc(vertical, horizontal: f32) -> Border {
	return Border{vertical, horizontal, vertical, horizontal}
}

// Individual border
border_trbl :: proc(top, right, bottom, left: f32) -> Border {
	return Border{top, right, bottom, left}
}

// Uniform border radius (all corners same)
border_radius_all :: proc(value: f32) -> base.Vec4 {
	return {value, value, value, value}
}

// Symmetric border radius (top corners, bottom corners)
border_radius_tb :: proc(top, bottom: f32) -> base.Vec4 {
	return {top, top, bottom, bottom}
}

// Individual border radius (top-left, top-right, bottom-right, bottom-left)
border_radius :: proc(tl, tr, br, bl: f32) -> base.Vec4 {
	return {tl, tr, br, bl}
}

// Fixed size
sizing_fixed :: proc(value: f32, min: f32 = 0, max: f32 = math.F32_MAX) -> Sizing {
	return Sizing{kind = .Fixed, value = value, min_value = min, max_value = max}
}

// Grow to fill available space
sizing_grow :: proc(min: f32 = 0, max: f32 = math.F32_MAX) -> Sizing {
	return Sizing{kind = .Grow, min_value = min, max_value = max}
}

// Fit to content
sizing_fit :: proc(min: f32 = 0, max: f32 = math.F32_MAX) -> Sizing {
	return Sizing{kind = .Fit, min_value = min, max_value = max}
}

// Percentage of parent size
sizing_percent :: proc(percent: f32, min: f32 = 0, max: f32 = math.F32_MAX) -> Sizing {
	return Sizing{kind = .Percentage_Of_Parent, value = percent, min_value = min, max_value = max}
}

// Uses Maybe(T) for optional simple types and tagged structs for unions (Fill).
// Zero-value fields mean "not set" and will inherit from stack or defaults.
Style :: struct {
	// Layout properties
	sizing_x:          Maybe(Sizing),
	sizing_y:          Maybe(Sizing),
	padding:           Maybe(Padding),
	margin:            Maybe(Margin),
	border:            Maybe(Border),
	border_radius:     Maybe(base.Vec4),
	child_gap:         Maybe(f32),
	layout_mode:       Maybe(Layout_Mode),
	layout_direction:  Maybe(Layout_Direction),
	relative_position: Maybe(base.Vec2),
	alignment_x:       Maybe(Alignment_X),
	alignment_y:       Maybe(Alignment_Y),
	text_alignment_x:  Maybe(Alignment_X),
	text_alignment_y:  Maybe(Alignment_Y),

	// Visual properties (uses tagged Fill - .Not_Set means "inherit")
	background_fill:   base.Fill,
	text_fill:         base.Fill,
	border_fill:       base.Fill,

	// Other
	clip:              Maybe(Clip_Config),
	capability_flags:  Maybe(Capability_Flags),
}

// Converts a Style struct to Element_Config by walking the style stack.
// Resolution order: default -> style_stack (bottom to top) -> user style
// Single-pass: walks the stack once and merges all styles together.
resolve_style :: proc(ctx: ^Context, style: Style, default_style: Style = {}) -> Element_Config {
	// Start with default, merge stack styles, then user style
	// Note: Stack uses 1-based indexing (items[1] to items[top])
	resolved := default_style
	for i: i32 = 1; i <= ctx.style_stack.top; i += 1 {
		resolved = merge_styles(resolved, ctx.style_stack.items[i])
	}
	resolved = merge_styles(resolved, style)

	// Capability flags are additive (OR together from all sources)
	capability_flags := resolve_capability_flags(ctx, style, default_style)

	// Convert merged Style to Element_Config
	return style_to_config(resolved, capability_flags)
}

// Converts a fully-resolved Style to Element_Config
@(private)
style_to_config :: proc(s: Style, capability_flags: Capability_Flags) -> Element_Config {
	config: Element_Config

	// Layout properties
	config.layout.sizing[Axis2.X] = s.sizing_x.? or_else Sizing{}
	config.layout.sizing[Axis2.Y] = s.sizing_y.? or_else Sizing{}
	config.layout.padding = s.padding.? or_else Padding{}
	config.layout.margin = s.margin.? or_else Margin{}
	config.layout.child_gap = s.child_gap.? or_else 0
	config.layout.layout_mode = s.layout_mode.? or_else Layout_Mode{}
	config.layout.layout_direction = s.layout_direction.? or_else Layout_Direction{}
	config.layout.relative_position = s.relative_position.? or_else base.Vec2{}
	config.layout.alignment_x = s.alignment_x.? or_else Alignment_X{}
	config.layout.alignment_y = s.alignment_y.? or_else Alignment_Y{}
	config.layout.text_alignment_x = s.text_alignment_x.? or_else Alignment_X{}
	config.layout.text_alignment_y = s.text_alignment_y.? or_else Alignment_Y{}
	config.layout.border_radius = s.border_radius.? or_else base.Vec4{}
	config.layout.border = s.border.? or_else Border{}

	// Visual properties (Fill) - use value if set, otherwise empty
	if s.background_fill.kind != .Not_Set {
		config.background_fill = s.background_fill
	}
	if s.text_fill.kind != .Not_Set {
		config.text_fill = s.text_fill
	}
	if s.border_fill.kind != .Not_Set {
		config.border_fill = s.border_fill
	}

	// Clip config
	config.clip = s.clip.? or_else Clip_Config{}

	// Capability flags (already computed additively)
	config.capability_flags = capability_flags

	return config
}

// Capability flags are additive - OR all set values together
@(private)
resolve_capability_flags :: proc(ctx: ^Context, style, default_style: Style) -> Capability_Flags {
	result: Capability_Flags

	// Add default flags
	if flags, ok := default_style.capability_flags.?; ok {
		result |= flags
	}

	// Add flags from style_stack (all levels, since they're additive)
	// Note: Stack uses 1-based indexing (items[1] to items[top])
	for i: i32 = 1; i <= ctx.style_stack.top; i += 1 {
		if flags, ok := ctx.style_stack.items[i].capability_flags.?; ok {
			result |= flags
		}
	}

	// Add user flags
	if flags, ok := style.capability_flags.?; ok {
		result |= flags
	}

	return result
}

// Theme holds default Styles for each widget type.
// Widgets use these as their default styles, which can be overridden per-call.
Theme :: struct {
	button:     Style,
	checkbox:   Style,
	label:      Style,
	panel:      Style,
	slider:     Style,
	spacer:     Style,
	text:       Style,
	text_input: Style,
}

default_theme :: proc() -> Theme {
	return Theme {
		button = Style {
			sizing_x = sizing_fit(),
			sizing_y = sizing_fit(),
			padding = padding_all(10),
			text_alignment_x = .Center,
			background_fill = base.fill_color(60, 60, 65),
			text_fill = base.fill_color(230, 230, 230),
			border_radius = border_radius_all(4),
			capability_flags = Capability_Flags{.Background, .Clickable, .Hot_Animation},
			clip = Clip_Config{clip_axes = {true, true}},
		},
		text_input = Style {
			alignment_x = .Left,
			alignment_y = .Center,
			text_alignment_y = .Center,
			sizing_x = sizing_grow(),
			sizing_y = sizing_fixed(48),
			padding = padding_xy(8, 12),
			background_fill = base.fill_color(30, 30, 35),
			text_fill = base.fill_color(230, 230, 230),
			border = border_all(0),
			border_fill = base.fill_color(80, 80, 85),
			border_radius = border_radius_all(4),
			capability_flags = Capability_Flags {
				.Background,
				.Clickable,
				.Focusable,
				.Hot_Animation,
			},
			layout_mode = .Relative,
			clip = Clip_Config{clip_axes = {true, true}},
		},
		text = Style {
			text_alignment_x = .Left,
			text_alignment_y = .Top,
			text_fill = base.fill_color(255, 255, 255),
			clip = Clip_Config{clip_axes = {true, true}},
		},
		checkbox = Style {
			sizing_x = sizing_fixed(24),
			sizing_y = sizing_fixed(24),
			background_fill = base.fill_color(45, 45, 50),
			border = border_all(2),
			border_fill = base.fill_color(80, 80, 85),
			border_radius = border_radius_all(4),
			capability_flags = Capability_Flags{.Background, .Clickable, .Hot_Animation},
		},
		slider = Style {
			sizing_x = sizing_grow(),
			sizing_y = sizing_fixed(20),
			background_fill = base.fill_color(40, 40, 45),
			border_radius = border_radius_all(2),
			capability_flags = Capability_Flags {
				.Background,
				.Clickable,
				.Focusable,
				.Hot_Animation,
			},
			layout_mode = .Relative,
		},
		spacer = Style{sizing_x = sizing_grow(), sizing_y = sizing_grow()},
		panel = Style {
			padding = padding_all(16),
			background_fill = base.fill_color(35, 35, 40),
			border_radius = border_radius_all(8),
			capability_flags = Capability_Flags{.Background},
		},
		label = Style{text_fill = base.fill_color(230, 230, 230)},
	}
}


// Merges two styles - style b overrides style a for any "set" fields
merge_styles :: proc(a, b: Style) -> Style {
	result := a

	// Layout properties - override if b has value
	if b.sizing_x != nil do result.sizing_x = b.sizing_x
	if b.sizing_y != nil do result.sizing_y = b.sizing_y
	if b.padding != nil do result.padding = b.padding
	if b.margin != nil do result.margin = b.margin
	if b.border != nil do result.border = b.border
	if b.border_radius != nil do result.border_radius = b.border_radius
	if b.child_gap != nil do result.child_gap = b.child_gap
	if b.layout_mode != nil do result.layout_mode = b.layout_mode
	if b.layout_direction != nil do result.layout_direction = b.layout_direction
	if b.relative_position != nil do result.relative_position = b.relative_position
	if b.alignment_x != nil do result.alignment_x = b.alignment_x
	if b.alignment_y != nil do result.alignment_y = b.alignment_y
	if b.text_alignment_x != nil do result.text_alignment_x = b.text_alignment_x
	if b.text_alignment_y != nil do result.text_alignment_y = b.text_alignment_y

	// Visual properties - override if b is set
	if b.background_fill.kind != .Not_Set do result.background_fill = b.background_fill
	if b.text_fill.kind != .Not_Set do result.text_fill = b.text_fill
	if b.border_fill.kind != .Not_Set do result.border_fill = b.border_fill

	// Other
	if b.clip != nil do result.clip = b.clip

	if b.capability_flags != nil do result.capability_flags = b.capability_flags

	return result
}

// Push a Style onto the style stack.
// Use with defer pop_style(ctx) to ensure proper cleanup.
// Only fields that are explicitly set will affect style resolution.
push_style :: proc(ctx: ^Context, style: Style) {
	push(&ctx.style_stack, style)
}

// Pop a Style from the style stack.
pop_style :: proc(ctx: ^Context) {
	pop(&ctx.style_stack)
}
