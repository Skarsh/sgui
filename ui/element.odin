package ui

import "core:container/small_array"
import "core:math"
import "core:testing"

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

attach_child :: proc(
	elements: ^UI_Elements,
	parent_ref: UI_Element_Ref,
	child_ref: UI_Element_Ref,
) {
	parent_idx := deref(elements^, parent_ref)
	parent := &elements.elements[parent_idx]

	child_idx := deref(elements^, child_ref)
	child := &elements.elements[child_idx]

	assert(parent_idx != child_idx)
	assert(child.parent_idx == 0 && child.next_sibling_idx == 0 && child.prev_sibling_idx == 0)

	child.parent_idx = parent_idx

	if parent.first_child_idx == 0 {
		// First child
		parent.first_child_idx = child_idx
		child.next_sibling_idx = child_idx
		child.prev_sibling_idx = child_idx
	} else {
		// Append sibling
		first_child_idx := parent.first_child_idx
		first_child := &elements.elements[first_child_idx]

		last_child_idx := first_child.prev_sibling_idx
		last_child := &elements.elements[last_child_idx]

		child.next_sibling_idx = first_child_idx
		child.prev_sibling_idx = last_child_idx

		last_child.next_sibling_idx = child_idx
		first_child.prev_sibling_idx = child_idx
	}
}

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

NIL_REF: UI_Element_Ref = {}

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

Child_Iterator :: struct {
	elements:        ^UI_Elements,
	idx:             int,
	first_child_idx: int,
	visited:         int,
	has_next:        bool,
}

@(require_results)
make_child_element_iterator :: proc(
	elements: ^UI_Elements,
	parent_ref: UI_Element_Ref,
) -> Child_Iterator {
	first_child_ref := get_first_child(elements^, parent_ref)
	has_next: bool

	if first_child_ref != NIL_REF {
		has_next = true
	}

	return {elements, first_child_ref.idx, first_child_ref.idx, 0, has_next}
}

@(require_results)
next_child_element :: proc(iter: ^Child_Iterator) -> (UI_Element_Ref, bool) {
	if iter.has_next {

		assert(iter.visited < MAX_ELEMENTS)

		child_ref := make_element_ref(iter.elements^, iter.idx)
		assert(is_valid_ref(iter.elements^, child_ref))
		sib_idx := get_next_sibling(iter.elements^, child_ref).idx

		// Next sibling idx is the same as first child, so we would wrap around on next.
		if sib_idx == iter.first_child_idx {
			iter.has_next = false
		} else {
			iter.idx = sib_idx
		}

		iter.visited += 1

		return child_ref, true

	} else {
		return NIL_REF, false
	}
}

Traversal_Order :: enum {
	Pre_Order,
	Post_Order,
	Reverse_Post_Order,
}

Tree_Iterator :: struct {
	elements: ^UI_Elements,
	root_idx: int,
	curr_idx: int,
	order:    Traversal_Order,
	visited:  int,
}

@(require_results)
make_tree_iterator :: proc(
	elements: ^UI_Elements,
	root_ref: UI_Element_Ref,
	order: Traversal_Order,
) -> Tree_Iterator {

	root_idx := deref(elements^, root_ref)

	curr_idx: int

	switch order {
	case .Pre_Order:
		curr_idx = root_idx
	case .Post_Order:
		curr_idx = descend_leftmost_idx(elements, root_idx)
	case .Reverse_Post_Order:
		unimplemented("Reverse_Post_Order traversal not implemented yet")
	}

	return {elements = elements, root_idx = root_idx, curr_idx = curr_idx, order = order}
}

@(require_results)
next_tree_element :: proc(iter: ^Tree_Iterator) -> (UI_Element_Ref, bool) {

	if iter.curr_idx == 0 {
		return NIL_REF, false
	}

	assert(iter.visited < MAX_ELEMENTS, "tree traversal exceeded MAX_ELEMENTS")
	iter.visited += 1

	current_idx := iter.curr_idx
	current_ref := make_element_ref(iter.elements^, current_idx)
	assert(is_valid_ref(iter.elements^, current_ref))

	switch iter.order {
	case .Pre_Order:
		iter.curr_idx = next_preorder_idx(iter.elements, iter.root_idx, current_idx)
	case .Post_Order:
		iter.curr_idx = next_postorder_idx(iter.elements, iter.root_idx, current_idx)
	case .Reverse_Post_Order:
		unimplemented("Reverse_Post_Order traversal not implemented yet")
	}

	return current_ref, true
}

@(private)
@(require_results)
next_preorder_idx :: proc(elements: ^UI_Elements, root_idx: int, current_idx: int) -> int {

	current := &elements.elements[current_idx]

	// 1. Descend into first child if present
	if current.first_child_idx != 0 {
		return current.first_child_idx
	}

	// 2. Climb until an ancestor has an unvisited next sibling, stopping at root_idx
	walk_idx := current_idx
	for _ in 0 ..< MAX_ELEMENTS {
		if walk_idx == root_idx {
			return 0
		}

		walk := &elements.elements[walk_idx]
		assert(walk.parent_idx != 0, "non-root node has no parent during tree traversal")
		assert(walk.next_sibling_idx != 0, "child node has broken sibling link")

		parent := &elements.elements[walk.parent_idx]
		if walk.next_sibling_idx != parent.first_child_idx {
			return walk.next_sibling_idx
		}

		walk_idx = walk.parent_idx

	}

	assert(false, "tree traversal climb exceeded MAX_ELEMENTS")
	return 0
}

@(private)
@(require_results)
descend_leftmost_idx :: proc(elements: ^UI_Elements, start_idx: int) -> int {

	walk_idx := start_idx
	for _ in 0 ..< MAX_ELEMENTS {
		first_child := elements.elements[walk_idx].first_child_idx
		if first_child == 0 {
			return walk_idx
		}
		walk_idx = first_child
	}

	assert(false, "tree traversal descent exceeded")
	return 0
}

@(private)
@(require_results)
next_postorder_idx :: proc(elements: ^UI_Elements, root_idx: int, current_idx: int) -> int {

	if current_idx == root_idx {
		return 0
	}

	current := &elements.elements[current_idx]
	assert(current.parent_idx != 0, "non-root node has no parent during tree traversal")
	assert(current.next_sibling_idx != 0, "child node has broken sibling link")

	parent := &elements.elements[current.parent_idx]
	if current.next_sibling_idx != parent.first_child_idx {
		return descend_leftmost_idx(elements, current.next_sibling_idx)
	}

	return current.parent_idx
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
		return NIL_REF
	} else {
		return make_element_ref(elements, elements.elements[slot].parent_idx)
	}
}

@(require_results)
get_first_child :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> UI_Element_Ref {
	slot := deref(elements, ref)
	if elements.elements[slot].first_child_idx == 0 {
		return NIL_REF
	} else {
		return make_element_ref(elements, elements.elements[slot].first_child_idx)
	}
}

@(require_results)
get_next_sibling :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> UI_Element_Ref {
	slot := deref(elements, ref)
	if elements.elements[slot].next_sibling_idx == 0 {
		return NIL_REF
	} else {
		return make_element_ref(elements, elements.elements[slot].next_sibling_idx)
	}
}

@(require_results)
get_prev_sibling :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> UI_Element_Ref {
	slot := deref(elements, ref)
	if elements.elements[slot].prev_sibling_idx == 0 {
		return NIL_REF
	} else {
		return make_element_ref(elements, elements.elements[slot].prev_sibling_idx)
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

	assert(element_ref != NIL_REF)

	if ctx.current_parent_ref != NIL_REF {
		attach_child(ctx.elements, ctx.current_parent_ref, element_ref)
	}

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

// TODO(Thomas): @Speed This could probably check if the element has fit sizing on
// any of the axes, because I'm pretty sure that's the only case where this really matters.
// The element's sizing mode (Fit, Fixed, Grow) determines how the text affects layout:
// - Fit: Element sizes to fit text content
// - Fixed: Element uses specified size, text renders within
// - Grow: Element can grow/shrink, text wraps as needed
measure_text_sizes_2 :: proc(ctx: ^Context, root_ref: UI_Element_Ref) {

	iter := make_tree_iterator(ctx.elements, root_ref, .Pre_Order)
	for ref in next_tree_element(&iter) {
		config := get_config(ctx.elements^, ref)

		if .Text in config.capability_flags {

			intrinsic := textpkg.measure_text_intrinsic(
				config.content.text_data.text,
				&ctx.text_system,
				config.layout.font_id,
			)

			text_content_size := intrinsic + get_box_sum(content_inset(config.layout))
			set_text_content_size(ctx.elements, ref, text_content_size)

			size := get_size(ctx.elements^, ref)

			if config.layout.sizing.x.kind != .Fixed {
				size.x = clamp_to_sizing(text_content_size.x, config.layout.sizing.x)
			}

			if config.layout.sizing.y.kind != .Fixed {
				size.y = clamp_to_sizing(text_content_size.y, config.layout.sizing.y)
			}

			set_size(ctx.elements, ref, size)
		}
	}
}

@(require_results)
calc_child_gap_2 :: proc(elements: ^UI_Elements, ref: UI_Element_Ref) -> f32 {
	flow_children: int
	iter := make_child_element_iterator(elements, ref)
	for child_ref in next_child_element(&iter) {
		child_config := get_config(elements^, child_ref)
		if child_config.layout.position_mode == .Flow {
			flow_children += 1
		}
	}

	child_gap := get_config(elements^, ref).layout.child_gap
	result := max(f32(flow_children - 1), 0) * child_gap
	assert(result >= 0, "child_gap must be >= 0")
	return result
}

@(require_results)
measure_flow_content_size_2 :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
) -> (
	content_size: base.Vec2,
) {
	dir := get_config(elements^, ref).layout.layout_direction
	main_axis, cross_axis := get_main_and_cross_axis(dir)

	iter := make_child_element_iterator(elements, ref)
	for child_ref in next_child_element(&iter) {
		child_config := get_config(elements^, child_ref)
		if child_config.layout.position_mode == .Flow {
			child_size := get_size(elements^, child_ref)
			child_margin := child_config.layout.margin
			margin_main := get_margin_sum_for_axis(child_margin, main_axis)
			margin_cross := get_margin_sum_for_axis(child_margin, cross_axis)

			content_size[main_axis] += child_size[main_axis] + margin_main
			content_size[cross_axis] = max(
				content_size[cross_axis],
				child_size[cross_axis] + margin_cross,
			)
		}
	}

	content_size[main_axis] += calc_child_gap_2(elements, ref)
	return
}

@(require_results)
calculate_element_size_for_axis_2 :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	axis: base.Axis2,
) -> f32 {

	config := get_config(elements^, ref)
	inset_sum := get_box_sum_for_axis(content_inset(config.layout), axis)

	content_size := measure_flow_content_size_2(elements, ref)[axis]
	total_size := content_size + inset_sum

	// text_content_size already includes padding and border
	if .Text in config.capability_flags {
		text_content_size := get_text_content_size(elements^, ref)
		total_size = max(total_size, text_content_size[axis])
	}

	total_size = clamp_to_sizing(total_size, config.layout.sizing[axis])

	assert(total_size >= 0)
	return total_size
}

measure_intrinsic_size_for_axis_2 :: proc(
	elements: ^UI_Elements,
	root_ref: UI_Element_Ref,
	axis: base.Axis2,
) {
	iter := make_tree_iterator(elements, root_ref, .Post_Order)

	for ref in next_tree_element(&iter) {
		config := get_config(elements^, ref)
		sizing_kind := config.layout.sizing[axis].kind
		if sizing_kind == .Fit || sizing_kind == .Grow {
			size := get_size(elements^, ref)
			size[axis] = calculate_element_size_for_axis_2(elements, ref, axis)
			set_size(elements, ref, size)
		}
	}
}

@(require_results)
content_box_2 :: proc(elements: UI_Elements, ref: UI_Element_Ref) -> Content_Box {

	config := get_config(elements, ref)
	inset := content_inset(config.layout)
	size := get_size(elements, ref)
	pos := get_position(elements, ref)

	available := size - get_box_sum(inset)
	result_size := base.Vec2 {
		math.clamp(available.x, 0, size.x),
		math.clamp(available.y, 0, size.y),
	}

	assert(result_size.x >= 0)
	assert(result_size.y >= 0)

	return Content_Box{origin = pos + {inset.left, inset.top}, size = result_size}
}

@(require_results)
is_main_axis_2 :: proc(layout_direction: Layout_Direction, axis: base.Axis2) -> bool {

	return(
		(axis == .X && layout_direction == .Left_To_Right) ||
		(axis == .Y && layout_direction == .Top_To_Bottom) \
	)

}

resolve_percentage_sizes_for_children_2 :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	axis: base.Axis2,
) {
	content_available_size := content_box_2(elements^, ref).size

	iter := make_child_element_iterator(elements, ref)
	for child_ref in next_child_element(&iter) {
		sizing_info := get_config(elements^, child_ref).layout.sizing[axis]
		if sizing_info.kind == .Percentage {
			size := get_size(elements^, child_ref)
			size[axis] = clamp_to_sizing(
				content_available_size[axis] * sizing_info.value,
				sizing_info,
			)
			set_size(elements, child_ref, size)
		}
	}
}

resolve_grow_sizes_for_children_2 :: proc(
	elements: ^UI_Elements,
	ref: UI_Element_Ref,
	axis: base.Axis2,
) {
	config := get_config(elements^, ref)
	main_axis := is_main_axis_2(config.layout.layout_direction, axis)
	content := content_box_2(elements^, ref)
	child_gap := calc_child_gap_2(elements, ref)
	available := content.size[axis] - child_gap

	sharing: small_array.Small_Array(MAX_ELEMENTS, UI_Element_Ref)

	iter := make_child_element_iterator(elements, ref)
	for child_ref in next_child_element(&iter) {
		child_config := get_config(elements^, child_ref)
		margins := get_margin_sum_for_axis(child_config.layout.margin, axis)
		sizing := child_config.layout.sizing[axis]

		if main_axis && child_config.layout.position_mode == .Flow {
			available -= margins
			if sizing.kind == .Grow && sizing.grow_factor > 0 {
				ok := small_array.append_elem(&sharing, child_ref)
				assert(ok)
			} else {
				available -= get_size(elements^, child_ref)[axis]
			}
		} else if sizing.kind == .Grow {
			// Cross axis or anchored
			size := get_size(elements^, child_ref)
			size[axis] = clamp_to_sizing(content.size[axis] - margins, sizing)
			set_size(elements, child_ref, size)
		}
	}

	unresolved := small_array.slice(&sharing)
	progress := true

	for len(unresolved) > 0 && progress {
		sum_factors: f32 = 0
		for child_ref in unresolved {
			sum_factors += get_config(elements^, child_ref).layout.sizing[axis].grow_factor
		}

		size_per_factor := available / sum_factors
		total: f32 = 0

		for child_ref in unresolved {
			sizing := get_config(elements^, child_ref).layout.sizing[axis]
			size := get_size(elements^, child_ref)
			size[axis] = clamp_to_sizing(sizing.grow_factor * size_per_factor, sizing)
			set_size(elements, child_ref, size)
			total += size[axis]
		}

		too_big := total > available
		kept := 0
		for child_ref in unresolved {
			sizing := get_config(elements^, child_ref).layout.sizing[axis]
			child_size_axis := get_size(elements^, child_ref)[axis]
			limit := too_big ? sizing.min_value : sizing.max_value
			if child_size_axis == limit {
				available -= child_size_axis
			} else {
				unresolved[kept] = child_ref
				kept += 1
			}
		}

		progress = kept < len(unresolved)
		unresolved = unresolved[:kept]
	}
}

resolve_dependent_sizes_for_axis_2 :: proc(
	elements: ^UI_Elements,
	root_ref: UI_Element_Ref,
	axis: base.Axis2,
) {
	iter := make_tree_iterator(elements, root_ref, .Pre_Order)
	for ref in next_tree_element(&iter) {
		resolve_percentage_sizes_for_children_2(elements, ref, axis)
		resolve_grow_sizes_for_children_2(elements, ref, axis)
	}
}

// ------------- Testing ------------- //

@(private)
Tree_Edge :: struct {
	parent: string,
	child:  string,
}

@(private)
find_ref_by_name :: proc(elements: UI_Elements, name: string) -> UI_Element_Ref {
	for i in 1 ..< MAX_ELEMENTS {
		if elements.used[i] && elements.elements[i].name == name {
			return make_element_ref(elements, i)
		}
	}

	assert(false, "test element not found")
	return NIL_REF
}

@(private)
build_test_tree :: proc(elements: ^UI_Elements, names: []string, edges: []Tree_Edge) {
	init_ui_elements(elements)

	for name, i in names {
		for prev in names[:i] {
			assert(prev != name, "duplicate element name in test tree")
		}
		ref := add_element(elements, {}, {}, name)
		assert(ref != NIL_REF)
	}

	for edge in edges {
		parent_ref := find_ref_by_name(elements^, edge.parent)
		child_ref := find_ref_by_name(elements^, edge.child)
		attach_child(elements, parent_ref, child_ref)
	}
}

@(private)
check_children :: proc(
	t: ^testing.T,
	names: []string,
	edges: []Tree_Edge,
	target: string,
	expected: []string,
	loc := #caller_location,
) {
	elements := new(UI_Elements)
	defer free(elements)

	build_test_tree(elements, names, edges)

	target_ref := find_ref_by_name(elements^, target)
	iter := make_child_element_iterator(elements, target_ref)

	for expected_name in expected {
		child, ok := next_child_element(&iter)
		if !testing.expect(t, ok, "child iterator ended early", loc = loc) {
			return
		}

		testing.expect_value(t, get_name(elements^, child), expected_name, loc = loc)
		testing.expect_value(t, get_parent(elements^, child), target_ref, loc = loc)
	}

	// Verify exhaustion stays false across repeated calls
	for _ in 0 ..< 2 {
		child, ok := next_child_element(&iter)
		testing.expect_value(t, ok, false, loc = loc)
		testing.expect_value(t, child, NIL_REF, loc = loc)
	}
}

@(private)
check_tree_traversal :: proc(
	t: ^testing.T,
	order: Traversal_Order,
	names: []string,
	edges: []Tree_Edge,
	start: string,
	expected: []string,
	loc := #caller_location,
) {

	elements := new(UI_Elements)
	defer free(elements)

	build_test_tree(elements, names, edges)

	start_ref := find_ref_by_name(elements^, start)
	iter := make_tree_iterator(elements, start_ref, order)

	for expected_name in expected {
		elem, ok := next_tree_element(&iter)
		if !testing.expect(t, ok, "tree iterator ended early", loc = loc) {
			return
		}

		testing.expect_value(t, get_name(elements^, elem), expected_name, loc = loc)
	}

	for _ in 0 ..< 2 {
		elem, ok := next_tree_element(&iter)
		testing.expect_value(t, ok, false, loc = loc)
		testing.expect_value(t, elem, NIL_REF, loc = loc)
	}
}

@(test)
test_child_iterator_no_children :: proc(t: ^testing.T) {
	check_children(t, {"root"}, nil, "root", nil)
}

@(test)
test_child_iterator_single_child :: proc(t: ^testing.T) {
	check_children(t, {"root", "a"}, {{"root", "a"}}, "root", {"a"})
}

@(test)
test_child_iterator_multiple_children :: proc(t: ^testing.T) {
	check_children(
		t,
		{"root", "a", "b", "c"},
		{{"root", "a"}, {"root", "b"}, {"root", "c"}},
		"root",
		{"a", "b", "c"},
	)
}

@(test)
test_child_iterator_reversed_attach_order :: proc(t: ^testing.T) {
	check_children(
		t,
		{"root", "a", "b", "c"},
		{{"root", "c"}, {"root", "b"}, {"root", "a"}},
		"root",
		{"c", "b", "a"},
	)
}

@(test)
test_child_iterator_nested_hierarchy :: proc(t: ^testing.T) {
	names := []string{"root", "a", "b", "a1", "a2"}
	edges := []Tree_Edge{{"root", "a"}, {"root", "b"}, {"a", "a1"}, {"a", "a2"}}

	check_children(t, names, edges, "root", {"a", "b"})
	check_children(t, names, edges, "a", {"a1", "a2"})
	check_children(t, names, edges, "b", nil)
}

@(test)
test_tree_iterator_preorder_single_node :: proc(t: ^testing.T) {
	check_tree_traversal(t, .Pre_Order, {"root"}, nil, "root", {"root"})
}

@(test)
test_tree_iterator_preorder_chain :: proc(t: ^testing.T) {
	check_tree_traversal(
		t,
		.Pre_Order,
		{"root", "a", "b", "c"},
		{{"root", "a"}, {"a", "b"}, {"b", "c"}},
		"root",
		{"root", "a", "b", "c"},
	)
}

@(test)
test_tree_iterator_preorder_flat_siblings :: proc(t: ^testing.T) {
	check_tree_traversal(
		t,
		.Pre_Order,
		{"root", "a", "b", "c"},
		{{"root", "a"}, {"root", "b"}, {"root", "c"}},
		"root",
		{"root", "a", "b", "c"},
	)
}

@(test)
test_tree_iterator_preorder_mixed_tree :: proc(t: ^testing.T) {
	names := []string{"root", "a", "a1", "a2", "a2_1", "b", "c", "c1"}
	edges := []Tree_Edge {
		{"root", "a"},
		{"root", "b"},
		{"root", "c"},
		{"a", "a1"},
		{"a", "a2"},
		{"a2", "a2_1"},
		{"c", "c1"},
	}

	check_tree_traversal(
		t,
		.Pre_Order,
		names,
		edges,
		"root",
		{"root", "a", "a1", "a2", "a2_1", "b", "c", "c1"},
	)
}

@(test)
test_tree_iterator_preorder_subtree :: proc(t: ^testing.T) {
	names := []string{"root", "a", "a1", "a2", "a2_1", "b", "c"}
	edges := []Tree_Edge {
		{"root", "a"},
		{"root", "b"},
		{"root", "c"},
		{"a", "a1"},
		{"a", "a2"},
		{"a2", "a2_1"},
	}

	// Subtree with children must not leak into b or c
	check_tree_traversal(t, .Pre_Order, names, edges, "a", {"a", "a1", "a2", "a2_1"})
	// Leaf subtree with siblings must only yield itself
	check_tree_traversal(t, .Pre_Order, names, edges, "b", {"b"})
}

@(test)
test_tree_iterator_postorder_single_node :: proc(t: ^testing.T) {
	check_tree_traversal(t, .Post_Order, {"root"}, nil, "root", {"root"})
}

@(test)
test_tree_iterator_postorder_chain :: proc(t: ^testing.T) {
	check_tree_traversal(
		t,
		.Post_Order,
		{"root", "a", "b", "c"},
		{{"root", "a"}, {"a", "b"}, {"b", "c"}},
		"root",
		{"c", "b", "a", "root"},
	)
}

@(test)
test_tree_iterator_postorder_flat_siblings :: proc(t: ^testing.T) {
	check_tree_traversal(
		t,
		.Post_Order,
		{"root", "a", "b", "c"},
		{{"root", "a"}, {"root", "b"}, {"root", "c"}},
		"root",
		{"a", "b", "c", "root"},
	)
}

@(test)
test_tree_iterator_postorder_mixed_tree :: proc(t: ^testing.T) {
	names := []string{"root", "a", "a1", "a2", "a2_1", "b", "c", "c1"}
	edges := []Tree_Edge {
		{"root", "a"},
		{"root", "b"},
		{"root", "c"},
		{"a", "a1"},
		{"a", "a2"},
		{"a2", "a2_1"},
		{"c", "c1"},
	}

	check_tree_traversal(
		t,
		.Post_Order,
		names,
		edges,
		"root",
		{"a1", "a2_1", "a2", "a", "b", "c1", "c", "root"},
	)
}

@(test)
test_tree_iterator_postorder_subtree :: proc(t: ^testing.T) {

	names := []string{"root", "a", "a1", "a2", "a2_1", "b", "c"}
	edges := []Tree_Edge {
		{"root", "a"},
		{"root", "b"},
		{"root", "c"},
		{"a", "a1"},
		{"a", "a2"},
		{"a2", "a2_1"},
	}

	check_tree_traversal(t, .Post_Order, names, edges, "a", {"a1", "a2_1", "a2", "a"})
	check_tree_traversal(t, .Post_Order, names, edges, "b", {"b"})
}
