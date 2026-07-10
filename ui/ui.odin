package ui

import "core:log"
import "core:mem"

import "../base"
import textpkg "../text"

ELEMENT_STACK_SIZE :: 64
STYLE_STACK_SIZE :: 64

Color_Type :: enum u32 {
	Text,
	Selection_BG,
	Window_BG,
	Hot,
	Active,
	Base,
	Click,
}

Color_Style :: [Color_Type]base.Color

Context :: struct {
	persistent_allocator: mem.Allocator,
	frame_allocator:      mem.Allocator,
	draw_cmd_allocator:   mem.Allocator,
	element_stack:        Stack(^UI_Element, ELEMENT_STACK_SIZE),
	// Style stack for cascading styles. Use push_style/pop_style.
	style_stack:          Stack(Style, STYLE_STACK_SIZE),
	draw_state:           Draw_State,
	current_parent:       ^UI_Element,
	root_element:         ^UI_Element,
	interaction:          Interaction,
	element_cache:        map[UI_Key]^UI_Element,
	frame_idx:            u64,
	dt:                   f32,
	// TODO(Thomas): Does font size and font id belong here??
	font_size:            f32,
	font_id:              textpkg.Font_Handle,
	window_size:          [2]i32,
}

Capability :: enum {
	Background,
	Text,
	Image,
	Shape,
	Active_Animation,
	Hot_Animation,
	Clickable,
	Focusable,
	Scrollable_X,
	Scrollable_Y,
}

Capability_Flags :: bit_set[Capability]

default_color_style := Color_Style {
	.Text         = {230, 230, 230, 255},
	.Selection_BG = {90, 90, 90, 255},
	.Window_BG    = {50, 50, 50, 255},
	.Hot          = {95, 95, 95, 255},
	.Active       = {115, 115, 115, 255},
	.Base         = {30, 30, 30, 255},
	.Click        = {200, 200, 200, 255},
}

init :: proc(
	ctx: ^Context,
	input: ^base.Input,
	text_measurement: ^textpkg.Text_Measurement,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
	draw_cmd_allocator: mem.Allocator,
	screen_size: [2]i32,
	font_id: textpkg.Font_Handle,
	font_size: f32,
) {
	ctx^ = {} // zero memory
	ctx.interaction = Interaction {
		input            = input,
		text_measurement = text_measurement,
	}
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.draw_cmd_allocator = draw_cmd_allocator
	ctx.window_size = screen_size
	ctx.font_id = font_id
	ctx.font_size = font_size

	// TODO(Thomas): Pretty sure this can fail with allocation error as all other make procedures,
	// and is actually returning the error in an upcoming Odin version?
	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)

	init_draw_state_alloc_err := init_draw_state(&ctx.draw_state, draw_cmd_allocator)
	if init_draw_state_alloc_err != .None {
		log.error("Error when trying to init draw state: ", init_draw_state_alloc_err)
	}
	assert(init_draw_state_alloc_err == .None)

	init_interaction_alloc_err := init_interaction(&ctx.interaction, persistent_allocator)
	if init_interaction_alloc_err != .None {
		log.error("Error when trying to init interaction state", init_interaction_alloc_err)
	}
	assert(init_interaction_alloc_err == .None)
}

window_resize :: proc(ctx: ^Context, window_size: base.Vector2i32) {
	ctx.window_size = window_size
}

// TODO(Thomas): When we figure out a better allocation scheme for persistent stuf
// this can become better / cleaner.
deinit :: proc(ctx: ^Context) {

	deinit_interaction(&ctx.interaction)

	free_list, alloc_err := make([dynamic]^UI_Element, context.temp_allocator)
	assert(alloc_err == .None)
	defer free_all(context.temp_allocator)

	for _, elem in ctx.element_cache {
		if elem != nil {
			_, append_err := append(&free_list, elem)
			assert(append_err == .None)
		}
	}

	free_elements(free_list[:], ctx.persistent_allocator)

	// Delete the cache after we've freed the elements in the free_list
	delete(ctx.element_cache)
}

free_elements :: proc(free_list: []^UI_Element, allocator: mem.Allocator) {
	for elem in free_list {
		if elem.children != nil {
			delete(elem.children)
		}
		delete(elem.id_string)
		free(elem, allocator)
	}
}

begin :: proc(ctx: ^Context) -> bool {
	ctx.frame_idx += 1

	free_frame_alloc_err := free_all(ctx.frame_allocator)
	assert(free_frame_alloc_err == .None)

	free_draw_cmd_alloc_err := free_all(ctx.draw_cmd_allocator)
	assert(free_draw_cmd_alloc_err == .None)

	reset_interaction(&ctx.interaction)
	reset_draw_state(&ctx.draw_state, ctx.window_size)

	// Open the root element
	_, root_open_ok := open_element(
		ctx,
		"root",
		Style {
			sizing_x = sizing_fixed(f32(ctx.window_size.x)),
			sizing_y = sizing_fixed(f32(ctx.window_size.y)),
			background_fill = base.fill_color(128, 128, 128),
		},
	)
	assert(root_open_ok)
	root_element, _ := peek(&ctx.element_stack)

	//NOTE(Thomas): Root element size needs to be updated every frame, meaning not cached like other elements.
	// TODO(Thomas): We can maybe remove this special case by making the root be a NULL key type element, like a spacer.
	if root_element != nil {
		root_element.size.x = f32(ctx.window_size.x)
		root_element.size.y = f32(ctx.window_size.y)
	}

	ctx.root_element = root_element
	return root_open_ok
}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Fit sizing widths
	// 2. Update children cross axis widths
	// 3. Resolve dependent sizes widths
	// 4. Wrap text
	// 5. Fit sizing heights
	// 6. Update chilren cross axis heights
	// 7. Resolve dependent sizes heights
	// 8. Positions
	// 9. Process interactions
	// 10. Draw commands

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Fit sizing widths
	fit_size_axis(ctx.root_element, .X)

	// Update the cross axis size
	size_children_on_cross_axis(ctx.root_element, .X)

	// Resolve dependent widths
	resolve_dependent_sizes_for_axis(ctx.root_element, .X, ctx.frame_allocator)

	// Wrap text
	wrap_text(ctx, ctx.root_element, ctx.frame_allocator)

	// Fit sizing heights
	fit_size_axis(ctx.root_element, .Y)

	// Update the cross axis size
	size_children_on_cross_axis(ctx.root_element, .Y)

	// Reolve dependent heights
	resolve_dependent_sizes_for_axis(ctx.root_element, .Y, ctx.frame_allocator)

	calculate_positions_and_alignment(ctx.root_element, ctx.dt)

	process_interaction(&ctx.interaction, ctx.root_element, ctx.dt, ctx.frame_allocator)

	draw_all_elements(&ctx.draw_state, ctx.root_element)

	base.clear_input(ctx.interaction.input)

	prune_dead_elements(
		&ctx.element_cache,
		ctx.frame_idx,
		ctx.persistent_allocator,
		ctx.frame_allocator,
	)

}

// Prunes dead elements from the cache and the hierarchy
// Dead elements are elements which hasn't been had their last_frame_idx
// update in the last frame.
// TODO(Thomas): How would proper error handling here look?
prune_dead_elements :: proc(
	element_cache: ^map[UI_Key]^UI_Element,
	frame_idx: u64,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) {
	Elem :: struct {
		key:   UI_Key,
		value: ^UI_Element,
	}

	// Cannot alter map while iterating, so we make a free list
	free_list, alloc_err := make([dynamic]Elem, frame_allocator)
	assert(alloc_err == .None)

	for key, elem in element_cache {
		if elem != nil {
			if elem.last_frame_idx < frame_idx - 1 {
				_, alloc_err = append(&free_list, Elem{key, elem})
				assert(alloc_err == .None)
			}
		}
	}

	for elem in free_list {
		delete_key(element_cache, elem.key)
		if elem.value != nil {
			if elem.value.children != nil {
				delete(elem.value.children)
			}
			delete(elem.value.id_string)
			free_err := free(elem.value, persistent_allocator)
			assert(free_err == .None)
		}
	}
}
