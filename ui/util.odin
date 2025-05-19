package ui

import "core:math"

UI_Key :: struct {
	hash: u64,
}

ui_key_null :: proc() -> UI_Key {
	return UI_Key{hash = 0}
}

ui_key_hash :: proc(str: string) -> UI_Key {
	hash: u64 = 5381

	for b in transmute([]u8)str {
		hash = ((hash << 5) + hash) + u64(b)
	}

	return UI_Key{hash = hash}
}

ui_key_match :: proc(a, b: UI_Key) -> bool {
	return a.hash == b.hash
}

point_in_rect :: proc(p: Vector2i32, rect: Rect) -> bool {
	if p.x < rect.x || p.y < rect.y || p.x >= rect.x + rect.w || p.y >= rect.y + rect.h {
		return false
	}
	return true

}

intersect_rect :: proc(ctx: Context, rect: Rect) -> bool {
	if ctx.input.mouse_pos.x < rect.x ||
	   ctx.input.mouse_pos.y < rect.y ||
	   ctx.input.mouse_pos.x >= rect.x + rect.w ||
	   ctx.input.mouse_pos.y >= rect.y + rect.h {
		return false
	}
	return true
}

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

approx_equal :: proc(a: f32, b: f32, epsilon: f32) -> bool {
	return math.abs(a - b) <= epsilon
}
