package base

import "core:math"
import "core:testing"

@(require_results)
color_to_vec4 :: proc(color: Color) -> Vec4 {
	return Vec4{f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255}
}

@(require_results)
point_in_rect :: proc(p: Vector2i32, rect: Rect) -> bool {
	if p.x < rect.x || p.y < rect.y || p.x >= rect.x + rect.w || p.y >= rect.y + rect.h {
		return false
	}
	return true
}

@(require_results)
intersect_rects :: proc(r1, r2: Rect) -> Rect {
	x := max(r1.x, r2.x)
	y := max(r1.y, r2.y)

	r1_right := r1.x + r1.w
	r1_bottom := r1.y + r1.h

	r2_right := r2.x + r2.w
	r2_bottom := r2.y + r2.h

	right := min(r1_right, r2_right)
	bottom := min(r1_bottom, r2_bottom)

	// Ensure width and height are not negative
	w := max(0, right - x)
	h := max(0, bottom - y)

	return Rect{x, y, w, h}
}

@(require_results)
lerp_color :: proc(a, b: Color, t: f32) -> Color {
	t_clamped := math.clamp(t, 0.0, 1.0)

	color := Color {
		u8(math.lerp(f32(a.r), f32(b.r), t_clamped)),
		u8(math.lerp(f32(a.g), f32(b.g), t_clamped)),
		u8(math.lerp(f32(a.b), f32(b.b), t_clamped)),
		u8(math.lerp(f32(a.a), f32(b.a), t_clamped)),
	}

	return color
}

animate_vec2 :: proc(current: ^Vec2, target: ^Vec2, dt: f32, stiffness: f32) {
	if approx_equal_vec2(current^, target^, 0.001) {
		return
	}

	// Calculate smoothing factor
	t := 1.0 - math.pow(2.0, -stiffness * dt)

	apply_axis :: proc(c: ^f32, t: ^f32, factor: f32) {
		if math.abs(t^ - c^) < 0.1 {
			// Snap
			c^ = t^
		} else {
			c^ = math.lerp(c^, t^, factor)
		}
	}

	apply_axis(&current.x, &target.x, t)
	apply_axis(&current.y, &target.y, t)
}

@(require_results)
approx_equal :: proc(a: f32, b: f32, epsilon: f32) -> bool {
	return math.abs(a - b) <= epsilon
}

@(require_results)
approx_equal_vec2 :: proc(a: Vec2, b: Vec2, epsilon: f32) -> bool {
	return approx_equal(a.x, b.x, epsilon) && approx_equal(a.y, b.y, epsilon)
}

// Default tab width in number of spaces
TAB_WIDTH :: 4

// Calculate the visual width of a tab character based on space width
// tab_width: number of spaces a tab should occupy (defaults to TAB_WIDTH)
@(require_results)
calculate_tab_width :: proc(space_width: f32, tab_width: f32 = TAB_WIDTH) -> f32 {
	return space_width * tab_width
}

@(test)
test_calculate_tab_width_default :: proc(t: ^testing.T) {
	space_width: f32 = 10.0
	expected: f32 = space_width * TAB_WIDTH
	result := calculate_tab_width(space_width)
	testing.expect_value(t, result, expected)
}

@(test)
test_calculate_tab_width_custom :: proc(t: ^testing.T) {
	space_width: f32 = 10.0
	custom_tab_width: f32 = 8.0
	expected: f32 = space_width * custom_tab_width
	result := calculate_tab_width(space_width, custom_tab_width)
	testing.expect_value(t, result, expected)
}

@(test)
test_approx_equal_0_and_0 :: proc(t: ^testing.T) {
	a: f32 = 0
	b: f32 = 0
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), true)
}

@(test)
test_approx_equal_0_and_1 :: proc(t: ^testing.T) {
	a: f32 = 0
	b: f32 = 1
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), false)
}

@(test)
test_approx_equal_neg_1_and_0 :: proc(t: ^testing.T) {
	a: f32 = -1
	b: f32 = 0
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), false)
}

@(test)
test_approx_equal_neg_1_and_1 :: proc(t: ^testing.T) {
	a: f32 = -1
	b: f32 = 1
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), false)
}

@(test)
test_approx_equal_neg_1_and_neg_1 :: proc(t: ^testing.T) {
	a: f32 = -1
	b: f32 = -1
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), true)
}

@(test)
test_approx_equal_neg_1_and_neg_0999 :: proc(t: ^testing.T) {
	a: f32 = -1
	b: f32 = -0.999
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), true)
}

@(test)
test_approx_equal_neg_1_and_neg_0998 :: proc(t: ^testing.T) {
	a: f32 = -1
	b: f32 = -0.998
	epsilon: f32 = 0.001
	testing.expect_value(t, approx_equal(a, b, epsilon), false)
}

@(test)
intersect_rects_partial_overlap :: proc(t: ^testing.T) {
	r1 := Rect{10, 10, 20, 20}
	r2 := Rect{5, 5, 15, 15}
	intersected := intersect_rects(r1, r2)
	testing.expect_value(t, intersected, Rect{10, 10, 5 + 15 - 10, 5 + 15 - 10})
}

@(test)
intersect_rects_r1_inside_r2 :: proc(t: ^testing.T) {
	r1 := Rect{20, 20, 10, 10}
	r2 := Rect{20, 20, 20, 20}
	intersected := intersect_rects(r1, r2)
	testing.expect_value(t, intersected, Rect{20, 20, 20 + 10 - 20, 20 + 10 - 20})
}

@(test)
intersect_rects_r2_inside_r1 :: proc(t: ^testing.T) {
	r1 := Rect{10, 15, 10, 20}
	r2 := Rect{10, 15, 5, 10}
	intersected := intersect_rects(r1, r2)
	testing.expect_value(t, intersected, Rect{10, 15, 10 + 5 - 10, 15 + 10 - 15})
}

@(test)
intersect_rects_r2_outside_r1 :: proc(t: ^testing.T) {
	r1 := Rect{10, 10, 5, 5}
	r2 := Rect{0, 0, 2, 2}
	intersected := intersect_rects(r1, r2)
	testing.expect_value(t, intersected, Rect{10, 10, 0, 0})
}

@(test)
intersect_rects_r1_touches_r2 :: proc(t: ^testing.T) {
	r1 := Rect{10, 10, 5, 5}
	r2 := Rect{5, 5, 5, 5}
	intersected := intersect_rects(r1, r2)
	testing.expect_value(t, intersected, Rect{10, 10, 0, 0})
}
