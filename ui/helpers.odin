package ui

import base "../base"
import "core:math"

// =============================================================================
// Padding Constructors
// =============================================================================

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

// =============================================================================
// Margin Constructors
// =============================================================================

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

// =============================================================================
// Border Constructors
// =============================================================================

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

// =============================================================================
// Border Radius Constructors
// =============================================================================

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

// =============================================================================
// Sizing Constructors
// =============================================================================

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
