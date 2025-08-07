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
