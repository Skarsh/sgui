package ui

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

import "../base"
import textpkg "../text"
import "../text/fixed_buffer"

Comm :: struct {
	element:  ^UI_Element,
	active:   bool,
	hot:      bool,
	clicked:  bool,
	held:     bool,
	hovering: bool,
	text:     string,
}

Interaction :: struct {
	// input is owned by app
	input:               ^base.Input,
	// text_measurement is owned by app
	text_measurement:    ^textpkg.Text_Measurement,
	active_element:      ^UI_Element,
	hot_id:              UI_Key,
	pressed_id:          UI_Key,
	focused_id:          UI_Key,
	animatable_elements: [dynamic]^UI_Element,
}

@(require_results)
init_interaction :: proc(
	interaction: ^Interaction,
	allocator: mem.Allocator,
) -> mem.Allocator_Error {
	interaction.animatable_elements = make([dynamic]^UI_Element, allocator) or_return
	return nil
}

deinit_interaction :: proc(interaction: ^Interaction) {
	delete(interaction.animatable_elements)
}

reset_interaction :: proc(interaction: ^Interaction) {
	clear_dynamic_array(&interaction.animatable_elements)
}

Hit_Result :: struct {
	clickable:     ^UI_Element,
	scrollable:    ^UI_Element,
	focusable:     ^UI_Element,
	hot_animation: ^UI_Element,
}

@(require_results)
hit_test :: proc(root_element: ^UI_Element, pos: base.Vector2i32) -> Hit_Result {
	// TODO(Thomas): Make an iterative variant with explicit limitations
	// Depth-First-Search works here because a child will be drawn on top of it's parent.
	hit_test_recurse :: proc(element: ^UI_Element, pos: base.Vector2i32, out: ^Hit_Result) {
		assert(element != nil)
		assert(out != nil)
		if base.point_in_rect(pos, element_rect(element^)) {
			// children drawn last are on top, so we visit in reverse
			#reverse for child in element.children {
				hit_test_recurse(child, pos, out)
			}

			flags := element.config.capability_flags

			if out.clickable == nil && .Clickable in flags {
				out.clickable = element
			}

			if out.scrollable == nil && (.Scrollable_X in flags || .Scrollable_Y in flags) {
				out.scrollable = element
			}

			if out.focusable == nil && .Focusable in flags {
				out.focusable = element
			}

			if out.hot_animation == nil && .Hot_Animation in flags {
				out.hot_animation = element
			}

		} else {
			return
		}
	}


	result: Hit_Result
	hit_test_recurse(root_element, pos, &result)
	return result
}


update_interaction_ids :: proc(interaction: ^Interaction, hit_result: Hit_Result) {
	// hot_id is simply who is on top this frame, or nothing
	interaction.hot_id = hit_result.clickable != nil ? hit_result.clickable.key : {}

	if base.is_mouse_pressed(interaction.input^, .Left) {
		if hit_result.clickable != nil {
			interaction.pressed_id = hit_result.clickable.key

			// Click away: pressing anywhere clears the focused unless we land on a focusable
			if .Focusable in hit_result.clickable.config.capability_flags {
				interaction.focused_id = hit_result.clickable.key
			} else {
				interaction.focused_id = {}
			}
		} else {
			// Pressed on empty space, clear everything
			interaction.pressed_id = {}
			interaction.focused_id = {}
		}
	}

	if base.is_mouse_released(interaction.input^, .Left) {
		interaction.pressed_id = {}
	}
}


// TODO(Thomas): Move this?
@(private)
@(require_results)
focused_text_state :: proc(
	interaction: ^Interaction,
	ts: ^textpkg.Text_System,
) -> (
	^textpkg.Text_State,
	bool,
) {
	// TODO(Thomas): Could probably simplify this by pushing this if up to the call site
	if interaction.focused_id != ui_key_null() {
		if s, ok := &ts.text_states[interaction.focused_id.hash]; ok {
			return s, true
		}
	}

	return nil, false
}

// TODO(Thomas): Move this? If this take the text system and a key: u64 this
// can live in the text package, along with the Text_System type probably.
@(require_results)
get_text_state_selection :: proc(
	ts: ^textpkg.Text_System,
	element: UI_Element,
) -> (
	textpkg.Selection,
	bool,
) {

	if s, ok := ts.text_states[element.key.hash]; ok {
		return s.selection, true
	}

	return {}, false
}


// TODO(Thomas): Move this?
@(require_results)
focused_caret :: proc(ts: ^textpkg.Text_System, key: UI_Key) -> (byte_pos: int, ok: bool) {
	s, found := ts.text_states[key.hash]
	if found {
		byte_pos = s.selection.active
		ok = true
	}
	return
}

dispatch_mouse_to_focused :: proc(ctx: ^Context) {
	it := &ctx.interaction
	if it.focused_id != ui_key_null() {

		state, found := focused_text_state(it, &ctx.text_system)

		if found {
			focused_element, focused_found := get_element_by_key(ctx, it.focused_id)
			if focused_found {

				// Press sets the caret (collapsing the selection)
				// holding / dragging extends it.
				pressed := base.is_mouse_pressed(it.input^, .Left)
				held := base.is_mouse_down(it.input^, .Left)

				text_layout, found_layout := textpkg.read_text_layout_cache(
					ctx.text_system.layout_cache,
					focused_element.key.hash,
				)

				if found_layout {
					if pressed || held {
						origin := content_origin_scrolled(focused_element)
						byte_pos := textpkg.text_layout_byte_pos_from_point(
							text_layout,
							{
								f32(it.input.mouse_pos.x) - origin.x,
								f32(it.input.mouse_pos.y) - origin.y,
							},
						)

						textpkg.text_cursor_set_caret(
							state,
							textpkg.Cursor_Set_Caret{byte_pos, !pressed},
						)
					}
				}
			}
		}
	}
}

// TODO(Thomas): Find a better way than just pass the frame_allocator here?
// TODO(Thomas): Clean up error handling here, it's a little messy.
// TODO(Thomas): @Speed This runs every frame when an element is focused, which most likely is wasteful
dispatch_keyboard_to_focused :: proc(
	interaction: ^Interaction,
	ts: ^textpkg.Text_System,
	frame_allocator: mem.Allocator,
) {
	if interaction.focused_id != ui_key_null() {

		state, found := focused_text_state(interaction, ts)

		if found {
			// Text Input
			if interaction.input.text_input.len > 0 {
				text := string(
					interaction.input.text_input.data[:interaction.input.text_input.len],
				)

				text_buffer_error := textpkg.text_cursor_insert(
					state,
					textpkg.Cursor_Insert{text = text},
				)

				switch text_buffer_error {
				case fixed_buffer.Fixed_Buffer_Error.None, .Buffer_Full:
				case mem.Allocator_Error.None:
				case:
					panic(
						fmt.tprintf(
							"Error when inserting text into text buffer: %v",
							text_buffer_error,
						),
					)
				}
			}

			// Key handling
			keymod := interaction.input.keymod_down_bits
			keys := interaction.input.key_pressed_bits

			clipboard_command, text_handle_keys_error := textpkg.text_cursor_handle_keys(
				state,
				keys,
				keymod,
			)

			switch text_handle_keys_error {
			// Fixed buffer errors should be ignored
			case fixed_buffer.Fixed_Buffer_Error.None, .Buffer_Full:
			case mem.Allocator_Error.None:
			case:
				panic(fmt.tprintf("Error when trying handling keys: %v", text_handle_keys_error))
			}

			switch clipboard_command {
			case .None:
			case .Copy:
				//NOTE(Thomas): This will be freed when the frame_allocator is freed
				//TODO(Thomas): This can cause OOM for the frame_allocator if copying
				//very large text. We can think about using a fallback strategy of
				//persistent allocator or some general purpose allocator in those cases
				//when it has first failed with the frame allocator
				text, text_alloc_err := textpkg.text_cursor_get_text(state, frame_allocator)

				if text_alloc_err != .None {
					log.error("Error when trying to get text from text buffer: ", text_alloc_err)
				}
				assert(text_alloc_err == .None)

				selection := textpkg.text_cursor_get_selection(state)
				selection_start := textpkg.selection_start(selection)
				selection_end := textpkg.selection_end(selection)
				selection_text := text[selection_start:selection_end]

				interaction.input.clipboard_text_procs.set_clipboard_text_proc(
					selection_text,
					frame_allocator,
				)

			case .Paste:
				//TODO(Thomas): This can cause OOM for the frame_allocator if copying
				//very large text. We can think about using a fallback strategy of
				//persistent allocator or some general purpose allocator in those cases
				//when it has first failed with the frame allocator
				text_to_paste, alloc_err :=
					interaction.input.clipboard_text_procs.get_clipboard_text_proc(frame_allocator)
				if alloc_err != .None {
					log.error("Error when trying to get clipboard text: ", alloc_err)
				}
				assert(alloc_err == .None)

				// We don't crash just because someone tries to copy paste very large text
				text_insert_err := textpkg.text_cursor_insert(
					state,
					textpkg.Cursor_Insert{text = text_to_paste},
				)
				switch text_insert_err {
				case fixed_buffer.Fixed_Buffer_Error.None, mem.Allocator_Error.None:
				case .Buffer_Full:
					log.error("Cannot paste because fixed buffer is full error:", text_insert_err)
				case .Out_Of_Memory:
					log.error("Cannot paste because of Out Of Memory error:", text_insert_err)
				case:
					panic(fmt.tprintf("Unexpected error, cannot proceed: %v", text_insert_err))
				}
			case .Cut:
				// TODO(Thomas): Does this really need to be its own thing?
				// Isn't this just a copy selection but where the selection is deleted / removed before return??
				log.info("Cut clipboard command")
			}
		}
	}
}

apply_scroll :: proc(interaction: ^Interaction, scrollable: ^UI_Element) {
	if scrollable != nil {
		// Mouse wheel scrolling only makes sense in Y-axis
		if .Scrollable_Y in scrollable.config.capability_flags {
			if math.abs(interaction.input.scroll_delta.y) > 0 {
				// TODO(Thomas): This should probably be per element
				SCROLL_SPEED :: 30.0
				offset_delta := f32(interaction.input.scroll_delta.y) * SCROLL_SPEED

				scrollable.scroll_region.target_offset.y -= offset_delta

				scrollable.scroll_region.target_offset.y = math.clamp(
					scrollable.scroll_region.target_offset.y,
					0,
					scrollable.scroll_region.max_offset.y,
				)
			}
		}
	}
}

tween_animations :: proc(interaction: ^Interaction, dt: f32) {
	rate := (1.0 / 0.2) * dt

	for element in interaction.animatable_elements {
		flags := element.config.capability_flags

		if .Hot_Animation in flags {
			if element.key == interaction.hot_id || element.key == interaction.pressed_id {
				element.hot = math.clamp(element.hot + rate, 0, 1)
			} else {
				element.hot = math.clamp(element.hot - rate, 0, 1)
			}
		}

		if .Active_Animation in flags {
			if element.key == interaction.pressed_id {
				element.active = math.clamp(element.active + rate, 0, 1)
			} else {
				element.active = math.clamp(element.active - rate, 0, 1)
			}
		}
	}
}


// TODO(Thomas): Find a better way than just passing the frame allocator here?
process_interaction :: proc(ctx: ^Context) {
	// find hits
	mouse_pos := ctx.interaction.input.mouse_pos
	hit_result := hit_test(ctx.root_element, mouse_pos)

	// update interaction ids, e.g. hot, pressed, focused
	update_interaction_ids(&ctx.interaction, hit_result)

	dispatch_mouse_to_focused(ctx)
	dispatch_keyboard_to_focused(&ctx.interaction, &ctx.text_system, ctx.frame_allocator)

	apply_scroll(&ctx.interaction, hit_result.scrollable)

	tween_animations(&ctx.interaction, ctx.dt)
}

build_comm :: proc(
	interaction: ^Interaction,
	element: ^UI_Element,
) -> (
	comm: Comm,
	alloc_err: mem.Allocator_Error,
) {
	is_hot := element.key == interaction.hot_id
	is_pressed := element.key == interaction.pressed_id
	is_focused := element.key == interaction.focused_id

	flags := element.config.capability_flags

	if .Hot_Animation in flags || .Active_Animation in flags {
		append(&interaction.animatable_elements, element) or_return
	}

	clicked := is_hot && is_pressed && base.is_mouse_released(interaction.input^, .Left)

	return Comm {
			element = element,
			held = is_pressed,
			clicked = clicked,
			active = is_focused,
			hovering = is_hot || is_pressed,
			hot = base.approx_equal(element.hot, 1.0, 0.001),
		},
		nil
}
