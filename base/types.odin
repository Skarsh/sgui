package base

Color :: struct {
	r, g, b, a: u8,
}

Gradient :: struct {
	color_start: Color,
	color_end:   Color,
	direction:   Vec2, // Normalized direction vector, e.g. {1,0}=horizontal, {0,1}=vertical
}

Fill :: union {
	Color,
	Gradient,
}

// Convenience constructors for Fill
// Create a solid color fill from RGBA values
fill_color :: proc(r, g, b: u8, a: u8 = 255) -> Fill {
	return Color{r, g, b, a}
}

// Create a gradient fill
// direction is a normalized Vec2: {1,0}=left-to-right, {0,1}=top-to-bottom
fill_gradient :: proc(start, end: Color, direction: Vec2 = {0, 1}) -> Fill {
	return Gradient{start, end, direction}
}

Rect :: struct {
	x, y, w, h: i32,
}

Vec2 :: [2]f32
Vector2i32 :: [2]i32

Vec3 :: [3]f32
Vector3i32 :: [3]i32

Vec4 :: [4]f32
Vector4i32 :: [4]i32

Range :: struct {
	start: int,
	end:   int,
}
