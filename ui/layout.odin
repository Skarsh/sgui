package ui

import "core:log"
import "core:mem"

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
	id_string: string,
	position:  Vec2,
	size:      Vec2,
	padding:   Padding,
	child_gap: f32,
	children:  [dynamic]^UI_Element,
	color:     Color,
}

// TODO(Thomas): current parent probably has to be a pointer
open_element :: proc(ctx: ^Context, element: ^UI_Element) {
	push(&ctx.element_stack, element)
	ctx.current_parent = element
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
}

make_element :: proc(ctx: ^Context, id: string) -> (^UI_Element, bool) {

	key := ui_key_hash(id)

	element, found := ctx.element_cache[key]
	if !found {
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.persistent_allocator)
		if err != nil {
			log.error("failed to allocate UInelement")
			return nil, false
		}
		element.parent = ctx.current_parent
		element.id_string = id
		element.children = make([dynamic]^UI_Element, ctx.persistent_allocator)
		if element.parent != nil {
			append(&element.parent.children, element)
		}

		ctx.element_cache[key] = element
	}


	return element, true
}
