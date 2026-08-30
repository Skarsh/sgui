package ui

import "core:fmt"
import "core:mem"

import "../base"
import textpkg "../text"

ELEMENT_STACK_SIZE :: 64
STYLE_STACK_SIZE :: 64
ID_STACK_SIZE :: 64

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
	element_stack:        Stack(^UI_Element, ELEMENT_STACK_SIZE),
	// Style stack for cascading styles. Use push_style/pop_style.
	style_stack:          Stack(Style, STYLE_STACK_SIZE),
	// Id stack for making unique keys
	id_stack:             Stack(u64, ID_STACK_SIZE),
	draw_state:           Draw_State,
	current_parent:       ^UI_Element,
	root_element:         ^UI_Element,
	interaction:          Interaction,
	element_cache:        map[UI_Key]^UI_Element,
	frame_idx:            u64,
	dt:                   f32,
	font_configs:         []base.Font_Config,
	text_system:          textpkg.Text_System,
	window_size:          [2]i32,
}

Capability :: enum {
	Background,
	Text,
	Image,
	Shape,
	Active_Animation,
	Hot_Animation,
	Click_Animation,
	Clickable,
	Focusable,
	Selectable,
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
	draw_command_buffer: []Draw_Command,
	screen_size: [2]i32,
	font_configs: []base.Font_Config,
) {
	assert(len(draw_command_buffer) > 0)
	ctx^ = {} // zero memory
	ctx.interaction = Interaction {
		input            = input,
		text_measurement = text_measurement,
	}
	ctx.persistent_allocator = persistent_allocator
	ctx.frame_allocator = frame_allocator
	ctx.window_size = screen_size

	// TODO(Thomas): Pretty sure this can fail with allocation error as all other make procedures,
	// and is actually returning the error in an upcoming Odin version?
	ctx.element_cache = make(map[UI_Key]^UI_Element, persistent_allocator)

	ts_err := textpkg.init_text_system(
		&ctx.text_system,
		text_measurement^,
		font_configs,
		persistent_allocator,
	)
	assert(ts_err == .None)

	init_draw_state(&ctx.draw_state, draw_command_buffer)

	init_interaction_alloc_err := init_interaction(&ctx.interaction, persistent_allocator)
	assert(init_interaction_alloc_err == .None)
}

window_resize :: proc(ctx: ^Context, window_size: base.Vector2i32) {
	ctx.window_size = window_size
}

// TODO(Thomas): When we figure out a better allocation scheme for persistent stuf
// this can become better / cleaner.
deinit :: proc(ctx: ^Context) {

	// Deinit text system
	textpkg.deinit_text_system(&ctx.text_system, ctx.persistent_allocator)

	// Deinit interaction
	deinit_interaction(&ctx.interaction)

	for _, elem in ctx.element_cache {
		if elem != nil {
			free_element(elem, ctx.persistent_allocator)
		}
	}

	delete(ctx.element_cache)
}

free_element :: proc(elem: ^UI_Element, allocator: mem.Allocator) {
	if elem.children != nil {
		delete(elem.children)
	}
	delete(elem.name)

	free_err := free(elem, allocator)
	assert(free_err == .None)
}

begin :: proc(ctx: ^Context) {
	// Interaction runs against the tree that was laid out last frame.
	// Widgets see the input from this frame.
	// It is very important that this is the first thing that happens this frame
	// to make sure that memory from the preivous frame is valid for this to use.
	if ctx.root_element != nil {
		process_interaction(ctx)
	}

	clear(&ctx.id_stack)

	ctx.frame_idx += 1

	free_frame_alloc_err := free_all(ctx.frame_allocator)
	assert(free_frame_alloc_err == .None)

	reset_interaction(&ctx.interaction)
	reset_draw_state(&ctx.draw_state, ctx.window_size)

	// Open the root element
	root_element := open_element(
		ctx,
		ui_key_current_loc(),
		Style {
			sizing_x = sizing_fixed(f32(ctx.window_size.x)),
			sizing_y = sizing_fixed(f32(ctx.window_size.y)),
			background_fill = base.fill_color(128, 128, 128),
		},
		name = "root",
	)

	//NOTE(Thomas): Root element size needs to be updated every frame, meaning not cached like other elements.
	// TODO(Thomas): We can maybe remove this special case by making the root be a NULL key type element, like a spacer.
	if root_element != nil {
		root_element.size.x = f32(ctx.window_size.x)
		root_element.size.y = f32(ctx.window_size.y)
	}

	ctx.root_element = root_element
}

end :: proc(ctx: ^Context) {
	// Order of the operations we need to follow:
	// 1. Measure text sizes
	// 2. Measure intrinsic widths
	// 3. Resolve dependent sizes widths
	// 4. Wrap text
	// 5. Measure intrinsic heights
	// 6. Resolve dependent sizes heights
	// 7. Positions
	// 8. Draw commands

	// TODO(Thomas): Properly Log the name of the element that is not closed.
	if ctx.element_stack.top != 1 {
		panic(
			fmt.tprintf(
				"expected only the root element to be open at the end of the frame, got %v open",
				ctx.element_stack.top,
			),
		)
	}

	if !is_empty(&ctx.id_stack) {
		panic(
			fmt.tprintf(
				"expected the id_stack to be empty at the end of the frame, got %v oepn",
				ctx.id_stack.top,
			),
		)
	}

	// Close the root element
	close_element(ctx)
	assert(ctx.current_parent == nil)

	// Measure text sizes, intrinsic sizes of the text elements
	measure_text_sizes(ctx, ctx.root_element)

	// Measure intrinsic widths
	measure_intrinsic_size_for_axis(ctx.root_element, .X)

	// Resolve dependent widths
	resolve_width_alloc_err := resolve_dependent_sizes_for_axis(
		ctx.root_element,
		.X,
		ctx.frame_allocator,
	)
	assert(resolve_width_alloc_err == .None)

	// Wrap text
	wrap_text_alloc_err := wrap_text(ctx, ctx.root_element)
	assert(wrap_text_alloc_err == .None)

	// Measure intrinsic heights
	measure_intrinsic_size_for_axis(ctx.root_element, .Y)

	// Resolve dependent heights
	resolve_height_alloc_err := resolve_dependent_sizes_for_axis(
		ctx.root_element,
		.Y,
		ctx.frame_allocator,
	)
	assert(resolve_height_alloc_err == .None)

	calculate_positions_and_alignment(ctx, ctx.root_element, ctx.dt)

	draw_all_elements(ctx)

	base.clear_input(ctx.interaction.input)

	prune_dead_elements(
		&ctx.element_cache,
		ctx.frame_idx,
		ctx.persistent_allocator,
		ctx.frame_allocator,
	)

	prune_text_system_alloc_err := textpkg.prune_text_system(
		&ctx.text_system,
		ctx.frame_idx,
		ctx.persistent_allocator,
		ctx.frame_allocator,
	)
	assert(prune_text_system_alloc_err == .None)
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
			free_element(elem.value, persistent_allocator)
		}
	}
}
