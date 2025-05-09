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
	parent:           ^UI_Element,
	id_string:        string,
	position:         Vec2,
	size:             Vec2,
	sizing:           [2]Sizing,
	layout_direction: Layout_Direction,
	padding:          Padding,
	child_gap:        f32,
	children:         [dynamic]^UI_Element,
	color:            Color,
}

Sizing :: struct {
	kind:  Size_Kind,
	value: f32,
}

Element_Config :: struct {
	sizing:           [2]Sizing,
	layout_direction: Layout_Direction,
	color:            Color,
}

// TODO(Thomas): current parent probably has to be a pointer
open_element :: proc(ctx: ^Context, id: string, element_config: Element_Config) -> bool {

	element, element_ok := make_element(ctx, id)
	element.sizing = element_config.sizing
	element.position.x = 0
	element.position.y = 0
	element.size.x = element.sizing[0].value
	element.size.y = element.sizing[1].value
	element.color = element_config.color
	assert(element_ok)

	push(&ctx.element_stack, element) or_return
	ctx.current_parent = element
	return true
}

close_element :: proc(ctx: ^Context) {
	element, ok := pop(&ctx.element_stack)
	assert(ok)
	if ok {
		ctx.current_parent = element.parent

		if element.parent != nil {
			element.parent.size.x += element.size.x
			element.parent.size.y += element.size.y
		}
	}

	log.infof(
		"id_string: %s, size.x: %f, size.y: %f",
		element.id_string,
		element.size.x,
		element.size.y,
	)
}

make_element :: proc(ctx: ^Context, id: string) -> (^UI_Element, bool) {

	key := ui_key_hash(id)

	element, found := ctx.element_cache[key]
	if !found {
		err: mem.Allocator_Error
		element, err = new(UI_Element, ctx.persistent_allocator)
		if err != nil {
			log.error("failed to allocate UI_Element")
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
