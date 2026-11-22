package ui

import "core:container/small_array"
import "core:math"

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
	last_comm:               Comm_2,
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

// TODO(Thomas): Implement when needed, stubbed out for now
remove_element :: proc(elements: ^UI_Elements, ref: UI_Element_Ref) {}

// TODO(Thomas): Implement when needed, stubbed out for now
attach_child :: proc(
	elements: ^UI_Elements,
	parent_ref: UI_Element_Ref,
	child_ref: UI_Element_Ref,
) {}

find_empty :: proc(elements: ^UI_Elements) -> int {
	return elements.first_free
}

@(require_results)
is_valid_ref :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> bool {
	return(
		ref.idx > 0 &&
		ref.idx < MAX_ELEMENTS &&
		elements.used[ref.idx] &&
		elements.gen[ref.idx] == ref.gen \
	)
}

@(require_results)
deref :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> int {
	if is_valid_ref(elements, ref) {
		return ref.idx
	} else {
		assert(false, "Trying to deref a nil instance")
		return 0
	}
}

@(require_results)
make_element_ref :: proc(elements: UI_Elements, slot: int) -> UI_Element_Ref {
	return {idx = slot, gen = elements.gen[slot]}
}

nil_ref :: proc() -> UI_Element_Ref {
	return {}
}

// TODO(Thomas): Implement when needed, stubbed out for now
Elements_Iterator :: struct {}

// TODO(Thomas): Implement when needed, stubbed out for now
make_element_iterator :: proc(elements: ^UI_Elements) -> Elements_Iterator {
	return {}
}

// TODO(Thomas): Implement when needed, stubbed out for now
next_element :: proc(iter: ^Elements_Iterator) -> (UI_Element_Ref, bool) {
	return {}, false
}

// TODO(Thomas): Implement when needed, stubbed out for now
Child_Iterator :: struct {}

// TODO(Thomas): Implement when needed, stubbed out for now
make_child_element_iterator :: proc(elements: ^UI_Elements) -> Child_Iterator {
	return {}
}

// TODO(Thomas): Implement when needed, stubbed out for now
next_child_element :: proc(iter: ^Child_Iterator) -> (UI_Element_Ref, bool) {
	return {}, false
}

// ---------- Getters and Setters ---------- //


@(require_results)
get_name :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> string {
	return elements.elements[deref(elements, ref)].name
}

set_name :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, name: string) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].name = name
	}
}

@(require_results)
get_key :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> UI_Key {
	return elements.elements[deref(elements, ref)].key
}

set_key :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, key: UI_Key) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].key = key
	}
}

@(require_results)
get_position :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> base.Vec2 {
	return elements.elements[deref(elements, ref)].position
}

set_position :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, position: base.Vec2) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].position = position
	}
}

@(require_results)
get_size :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> base.Vec2 {
	return elements.elements[deref(elements, ref)].size
}

set_size :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, size: base.Vec2) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].size = size
	}
}

@(require_results)
get_text_content_size :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> base.Vec2 {
	return elements.elements[deref(elements, ref)].text_content_size
}


set_text_content_size :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	text_content_size: base.Vec2,
) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].text_content_size = text_content_size
	}
}

@(require_results)
get_scroll_region :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> Scroll_Region {
	return elements.elements[deref(elements, ref)].scroll_region
}

set_scroll_region :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	scroll_region: Scroll_Region,
) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].scroll_region = scroll_region
	}
}

@(require_results)
get_clip_rect :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> base.Rect {
	return elements.elements[deref(elements, ref)].clip_rect
}

set_clip_rect :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, clip_rect: base.Rect) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].clip_rect = clip_rect
	}
}

@(require_results)
get_config :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> Element_Config {
	return elements.elements[deref(elements, ref)].config
}

set_config :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, config: Element_Config) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].config = config
	}
}

@(require_results)
get_hot :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> f32 {
	return elements.elements[deref(elements, ref)].hot
}

set_hot :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, hot: f32) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].hot = hot
	}
}

@(require_results)
get_active :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> f32 {
	return elements.elements[deref(elements, ref)].active
}

set_active :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, active: f32) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].active = active
	}
}

@(require_results)
get_last_comm :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> Comm_2 {
	return elements.elements[deref(elements, ref)].last_comm
}

set_last_comm :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, last_comm: Comm_2) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].last_comm = last_comm
	}
}

@(require_results)
get_last_frame_idx :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> u64 {
	return elements.elements[deref(elements, ref)].last_frame_idx
}

set_last_frame_idx :: proc(elements: ^UI_Elements, ref: UI_Element_Ref, last_frame_idx: u64) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].last_frame_idx = last_frame_idx
	}
}

@(require_results)
get_text_state :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> textpkg.Text_State {
	return elements.elements[deref(elements, ref)].text_state
}

set_text_state :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	text_state: textpkg.Text_State,
) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].text_state = text_state
	}
}

@(require_results)
get_text_layout_cache_entry :: proc(
	elements: UI_Elements,
	ref: UI_Element_Ref,
) -> textpkg.Text_Layout_Cache_Entry {
	return elements.elements[deref(elements, ref)].text_layout_cache_entry
}

set_text_layout_cache_entry :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	text_layout_cache_entry: textpkg.Text_Layout_Cache_Entry,
) {
	if slot := deref(elements^, ref); b32(slot) {
		elements.elements[slot].text_layout_cache_entry = text_layout_cache_entry
	}
}

// ---------- Getters for child and parent fields ---------- //

@(require_results)
get_parent :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> UI_Element_Ref {
	slot := deref(elements, ref)
	if elements.elements[slot].parent_idx == 0 {
		return {}
	} else {
		return make_element_ref(elements, elements.elements[slot].parent_idx)
	}
}


// ---------- NEW LAYOUT IMPL FOR LAOTs ---------- //

Comm_2 :: struct {
	element_ref: UI_Element_Ref,
	active:      bool,
	hot:         bool,
	clicked:     bool,
	held:        bool,
	hovering:    bool,
	text:        string,
}

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

	if !push(&ctx.element_ref_stack, element_ref) {
		panic("Unable to push element ref onto stack, panic")
	}

	ctx.current_parent_ref = element_ref

	comm := build_comm_2(&ctx.interaction, ctx.elements^, element_ref)
	set_last_comm(ctx.elements, element_ref, comm)

	return element_ref
}

close_element_2 :: proc(ctx: ^Context) {
	ref, ok := pop(&ctx.element_ref_stack)
	assert(ok)
	if ok {
		ctx.current_parent_ref = get_parent(ctx.elements^, ref)
	}
}

begin_container_2 :: proc(
	ctx: ^Context,
	style: Style = {},
	name: string = "",
	id: string = "",
	loc := #caller_location,
) -> Comm_2 {
	key := ui_key(ctx, id, loc)
	element_ref := open_element_2(ctx, key, style, name = name)
	return get_last_comm(ctx.elements^, element_ref)
}

end_container_2 :: proc(ctx: ^Context) {
	close_element_2(ctx)
}

// TODO(Thomas): Think about using a get accessor to just get the element to retrieve
// fields like key, config and hot here, so do not have to call get accessor unnecessarily.
build_comm_2 :: proc(
	interaction: ^Interaction,
	elements: UI_Elements,
	ref: UI_Element_Ref,
) -> Comm_2 {

	key := get_key(elements, ref)
	if key == ui_key_null() {
		return Comm_2{element_ref = ref}
	}

	is_hot := key == interaction.hot_id
	is_pressed := key == interaction.pressed_id
	is_focused := key == interaction.focused_id
	is_clicked := key == interaction.clicked_id

	config := get_config(elements, ref)
	flags := config.capability_flags

	if .Hot_Animation in flags || .Active_Animation in flags {
		small_array.append_elem(&interaction.animatable_element_refs, ref)
	}

	hot := get_hot(elements, ref)

	return Comm_2 {
		element_ref = ref,
		held = is_pressed,
		clicked = is_clicked,
		active = is_focused,
		hovering = is_hot || is_pressed,
		hot = base.approx_equal(hot, 1.0, EPSILON),
	}
}

// TODO(Thomas): Think about using a get accessor to just get the element to retrieve
// fields like key, config and hot here, so do not have to call get accessor unnecessarily.
tween_animations_2 :: proc(interaction: ^Interaction, elements: ^UI_Elements, dt: f32) {
	FADE_SEC :: 0.2
	rate := (dt / FADE_SEC)

	for ref in small_array.slice(&interaction.animatable_element_refs) {

		key := get_key(elements^, ref)
		config := get_config(elements^, ref)
		flags := config.capability_flags
		hot := get_hot(elements^, ref)
		active := get_active(elements^, ref)

		if .Hot_Animation in flags {
			if key == interaction.hot_id || key == interaction.pressed_id {
				set_hot(elements, ref, math.clamp(hot + rate, 0, 1))
			} else {
				set_hot(elements, ref, math.clamp(hot - rate, 0, 1))
			}

			if .Active_Animation in flags {
				if key == interaction.pressed_id {
					set_active(elements, ref, math.clamp(active + rate, 0, 1))
				} else {
					set_active(elements, ref, math.clamp(active - rate, 0, 1))
				}
			}
		}
	}
}
