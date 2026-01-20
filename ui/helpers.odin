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

// Resolves a Maybe value: user -> stack -> default
@(private)
resolve_maybe :: proc(user: Maybe($T), stack: ^Stack(T, $N), default_value: T) -> T {
	if val, ok := user.?; ok {
		return val
	}

	if val, ok := peek(stack); ok {
		return val
	}

	return default_value
}

// Resolves a Fill value: user -> stack -> default (uses .Not_Set check)
@(private)
resolve_fill :: proc(
	user: base.Fill,
	stack: ^Stack(base.Fill, $N),
	default_value: base.Fill,
) -> base.Fill {
	if user.kind != .Not_Set {
		return user
	}

	if val, ok := peek(stack); ok && val.kind != .Not_Set {
		return val
	}

	return default_value
}

// Converts a Style struct to Element_Config using context stacks for defaults
resolve_style :: proc(ctx: ^Context, style: Style, default_style: Style = {}) -> Element_Config {
	config: Element_Config

	// Layout properties
	config.layout.sizing[Axis2.X] = resolve_maybe(
		style.sizing_x,
		&ctx.sizing_x_stack,
		style.sizing_x.? or_else (default_style.sizing_x.? or_else Sizing{}),
	)

	config.layout.sizing[Axis2.Y] = resolve_maybe(
		style.sizing_y,
		&ctx.sizing_y_stack,
		style.sizing_y.? or_else (default_style.sizing_y.? or_else Sizing{}),
	)

	config.layout.padding = resolve_maybe(
		style.padding,
		&ctx.padding_stack,
		style.padding.? or_else (default_style.padding.? or_else Padding{}),
	)

	config.layout.margin = resolve_maybe(
		style.margin,
		&ctx.margin_stack,
		style.margin.? or_else (default_style.margin.? or_else Margin{}),
	)

	config.layout.child_gap = resolve_maybe(
		style.child_gap,
		&ctx.child_gap_stack,
		style.child_gap.? or_else (default_style.child_gap.? or_else 0),
	)

	config.layout.layout_mode = resolve_maybe(
		style.layout_mode,
		&ctx.layout_mode_stack,
		style.layout_mode.? or_else (default_style.layout_mode.? or_else Layout_Mode{}),
	)

	config.layout.layout_direction = resolve_maybe(
		style.layout_direction,
		&ctx.layout_direction_stack,
		style.layout_direction.? or_else (default_style.layout_direction.? or_else Layout_Direction{}),
	)

	config.layout.relative_position = resolve_maybe(
		style.relative_position,
		&ctx.relative_position_stack,
		style.relative_position.? or_else (default_style.relative_position.? or_else base.Vec2{}),
	)

	config.layout.alignment_x = resolve_maybe(
		style.alignment_x,
		&ctx.alignment_x_stack,
		style.alignment_x.? or_else (default_style.alignment_x.? or_else Alignment_X{}),
	)

	config.layout.alignment_y = resolve_maybe(
		style.alignment_y,
		&ctx.alignment_y_stack,
		style.alignment_y.? or_else (default_style.alignment_y.? or_else Alignment_Y{}),
	)

	config.layout.text_alignment_x = resolve_maybe(
		style.text_alignment_x,
		&ctx.text_alignment_x_stack,
		style.text_alignment_x.? or_else (default_style.text_alignment_x.? or_else Alignment_X{}),
	)

	config.layout.text_alignment_y = resolve_maybe(
		style.text_alignment_y,
		&ctx.text_alignment_y_stack,
		style.text_alignment_y.? or_else (default_style.text_alignment_y.? or_else Alignment_Y{}),
	)

	config.layout.border_radius = resolve_maybe(
		style.border_radius,
		&ctx.border_radius_stack,
		style.border_radius.? or_else (default_style.border_radius.? or_else base.Vec4{}),
	)

	config.layout.border = resolve_maybe(
		style.border,
		&ctx.border_stack,
		style.border.? or_else (default_style.border.? or_else Border{}),
	)

	// Visual properties (Fill - use tagged resolution)
	config.background_fill = resolve_fill(
		style.background_fill,
		&ctx.background_fill_stack,
		default_style.background_fill.kind != .Not_Set ? default_style.background_fill : base.Fill{},
	)

	config.text_fill = resolve_fill(
		style.text_fill,
		&ctx.text_fill_stack,
		default_style.text_fill.kind != .Not_Set ? default_style.text_fill : base.Fill{},
	)

	config.border_fill = resolve_fill(
		style.border_fill,
		&ctx.border_fill_stack,
		default_style.border_fill.kind != .Not_Set ? default_style.border_fill : base.Fill{},
	)

	// Clip config
	config.clip = resolve_maybe(
		style.clip,
		&ctx.clip_stack,
		style.clip.? or_else (default_style.clip.? or_else Clip_Config{}),
	)

	// Capability flags are handled differently by being additive.
	// TODO(Thomas): Should the user specified flags completely override, e.g.
	// not OR but set directly?
	if flags, ok := default_style.capability_flags.?; ok {
		config.capability_flags |= flags
	}

	if stack_flags, stack_ok := peek(&ctx.capability_flags_stack); stack_ok {
		config.capability_flags |= stack_flags
	}

	if flags, ok := style.capability_flags.?; ok {
		config.capability_flags |= flags
	}

	return config
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
