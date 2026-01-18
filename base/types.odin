package base

Color :: struct {
	r, g, b, a: u8,
}

Gradient :: struct {
	color_start: Color,
	color_end:   Color,
	direction:   Vec2, // Normalized direction vector, e.g. {1,0}=horizontal, {0,1}=vertical
}

// Fill_Kind determines what type of fill is used
// Not_Set: Style resolution will inherit from stack/default
// None: Explicitly no fill (transparent)
// Solid: Solid color fill
// Gradient: Gradient fill
Fill_Kind :: enum u8 {
	Not_Set,
	None,
	Solid,
	Gradient,
}

// Tagged struct to work around Odin compiler bug with Maybe(union)
Fill :: struct {
	kind:    Fill_Kind,
	using _: struct #raw_union {
		color:    Color,
		gradient: Gradient,
	},
}

// Convenience constructors for Fill

// Create a solid color fill from RGBA values
fill_color :: proc(r, g, b: u8, a: u8 = 255) -> Fill {
	return Fill{kind = .Solid, color = Color{r, g, b, a}}
}

// Create a solid color fill from a Color struct
fill :: proc(color: Color) -> Fill {
	return Fill{kind = .Solid, color = color}
}

// Create a gradient fill
// direction is a normalized Vec2: {1,0}=left-to-right, {0,1}=top-to-bottom
fill_gradient :: proc(start, end: Color, direction: Vec2 = {0, 1}) -> Fill {
	return Fill{kind = .Gradient, gradient = Gradient{start, end, direction}}
}

// Explicitly no fill (transparent)
fill_none :: proc() -> Fill {
	return Fill{kind = .None}
}

// Check if a fill is set (not the default zero value)
fill_is_set :: proc(f: Fill) -> bool {
	return f.kind != .Not_Set
}

// Common fill helper procs (can't be constants due to #raw_union)
fill_white :: proc() -> Fill {
	return Fill{kind = .Solid, color = {255, 255, 255, 255}}
}

fill_black :: proc() -> Fill {
	return Fill{kind = .Solid, color = {0, 0, 0, 255}}
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
