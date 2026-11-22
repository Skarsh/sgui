package ui

import base "../base"
import textpkg "../text"

MAX_ELEMENTS :: 1024

UI_Element_2 :: struct {
	name:                    string,
	key:                     UI_Key,
	position:                base.Vec2,
	size:                    base.Vec2,
	text_content_size:       base.Vec2,
	scroll_region:           Scroll_Region,
	clip_rect:               base.Rect,
	config:                  Element_Config,
	hot:                     f32,
	active:                  f32,
	last_comm:               Comm,
	last_frame_idx:          u64,
	text_state:              textpkg.Text_State,
	text_layout_cache_entry: textpkg.Text_Layout_Cache_Entry,

	// Child stuff
	parent_idx:              int,
	first_child_idx:         int,
	next_sibling_idx:        int,
	prev_sibling_idx:        int,
}

UI_Element_Ref :: struct {
	idx: int,
	gen: int,
}

UI_Elements :: struct {
	elements:   [MAX_ELEMENTS]UI_Element_2,
	used:       [MAX_ELEMENTS]bool,
	gen:        [MAX_ELEMENTS]int,
	next_free:  [MAX_ELEMENTS]int,
	first_free: int,
}

init_ui_elements :: proc(elements: ^UI_Elements) {
	// Init the free list, starting at idx 1, since the 0th index is the nil instance.
	elements.first_free = 1

	// Initialize the free list
	for i in 1 ..< MAX_ELEMENTS {
		if i + 1 < MAX_ELEMENTS {
			elements.next_free[i] = i + 1
		} else {
			// This is the free element when initializing the free list.
			// This one points to the nil element because there are no
			// more free elements.
			elements.next_free[i] = 0
		}
	}
}

add_element :: proc(
	elements: ^UI_Elements,
	key: UI_Key,
	element_config: Element_Config,
	name: string,
) -> UI_Element_Ref {

	slot := find_empty(elements)

	if b32(slot) {

		// slot is the non-nil slot, so we can use it
		elements.elements[slot] = {}
		elements.elements[slot].key = key
		elements.elements[slot].config = element_config
		elements.elements[slot].name = name
		elements.used[slot] = true
		elements.gen[slot] += 1

		// The first_free needs to point to the next free at it's index.
		elements.first_free = elements.next_free[slot]

		// This slot is now taken, so the next_free for this slot / idx
		// should be updated to point to nil.
		elements.next_free[slot] = 0
		return {slot, elements.gen[slot]}

	} else {
		return {}
	}
}

find_empty :: proc(elements: ^UI_Elements) -> int {
	return elements.first_free
}


// NEW LAYOUT IMPL FOR LAOTs

@(require_results)
open_element_2 :: proc(
	ctx: ^Context,
	key: UI_Key,
	style: Style = {},
	default_style: Style = {},
	name: string = "",
) -> UI_Element_Ref {

	final_config := resolve_style(ctx, style, default_style)

	element_ref := add_element(ctx.elements, key, final_config, name)

	assert(element_ref != {})

	//ctx.current_parent = element

	//comm, comm

	return {}
}
