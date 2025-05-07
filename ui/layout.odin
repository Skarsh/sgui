package ui

import "core:log"

Layout_Direction :: enum {
	Left_To_Right,
	Top_To_Bottom,
}

Size_Kind :: enum {
	Fixed,
	Fit,
	Grow,
}

Padding :: struct {
	left:   f32,
	right:  f32,
	top:    f32,
	bottom: f32,
}

UI_Element :: struct {
	parent:    ^UI_Element,
	position:  Vec2,
	size:      Vec2,
	padding:   Padding,
	child_gap: f32,
	children:  [dynamic]UI_Element,
	color:     Color,
}

// TODO(Thomas): current parent probably has to be a pointer
open_element :: proc(ctx: ^Context, element: UI_Element) {
	push(&ctx.element_stack, element)
	ctx.current_parent = element
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
}

make_element :: proc(ctx: ^Context, id: string) -> UI_Element {

	return UI_Element{}
}
