package base

import "core:math"
import "core:testing"

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

@(require_results)
approx_equal :: proc(a: f32, b: f32, epsilon: f32) -> bool {
	return math.abs(a - b) <= epsilon
}

@(require_results)
approx_equal_vec2 :: proc(a: Vec2, b: Vec2, epsilon: f32) -> bool {
	return approx_equal(a.x, b.x, epsilon) && approx_equal(a.y, b.y, epsilon)
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
