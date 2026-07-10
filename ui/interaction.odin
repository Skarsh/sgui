package ui

import "core:log"
import "core:math"
import "core:mem"

import "../base"
import textpkg "../text"

Comm :: struct {
	element:  ^UI_Element,
	active:   bool,
	hot:      bool,
	clicked:  bool,
	held:     bool,
	hovering: bool,
	text:     string,
}

Text_Input_State :: struct {
	state:             textpkg.Text_Edit_State,
	caret_blink_timer: f32,
}

Interaction :: struct {
	// input is owned by app
	input:               ^base.Input,
	// text_measurement is owned by app
	text_measurement:    ^textpkg.Text_Measurement,
	text_input_states:   map[UI_Key]Text_Input_State,
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
	// NOTE(Thomas): make(map) does not return an Allocator_Error in this Odin
	// version (unlike make([dynamic])), so there is nothing to propagate here yet.
	interaction.text_input_states = make(map[UI_Key]Text_Input_State, allocator)
	interaction.animatable_elements = make([dynamic]^UI_Element, allocator) or_return
	return nil
}

deinit_interaction :: proc(interaction: ^Interaction) {
	for key in interaction.text_input_states {
		state := &interaction.text_input_states[key]
		textpkg.text_buffer_deinit(&state.state.buffer)
	}
	delete(interaction.text_input_states)
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
			// chlidren drawn last are on top, so we visit in reverse
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

// TODO(Thomas): Find a better way than just pass the frame_allocator here?
dispatch_keyboard_to_focused :: proc(interaction: ^Interaction, frame_allocator: mem.Allocator) {
	if interaction.focused_id != ui_key_null() {
		state, ok := &interaction.text_input_states[interaction.focused_id]
		if ok {
			// Text Input
			if interaction.input.text_input.len > 0 {
				text := string(
					interaction.input.text_input.data[:interaction.input.text_input.len],
				)
				textpkg.text_edit_insert(&state.state, text)
			}

			// Key handling
			keymod := interaction.input.keymod_down_bits
			keys := interaction.input.key_pressed_bits
			clipboard_command := textpkg.text_edit_handle_keys(&state.state, keys, keymod)

			switch clipboard_command {
			case .None:
			case .Copy:
				selection := state.state.selection

				//NOTE(Thomas): This will be freed when the frame_allocator is freed
				//TODO(Thomas): This can cause OOM for the frame_allocator if copying
				//very large text. We can think about using a fallback strategy of
				//persistent allocator or some general purpose allocator in those cases
				//when it has first failed with the frame allocator
				text, text_alloc_err := textpkg.text_buffer_text(
					state.state.buffer,
					frame_allocator,
				)
				if text_alloc_err != .None {
					log.error("Error when trying to get text from text buffer: ", text_alloc_err)
				}
				assert(text_alloc_err == .None)

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
					log.error("Eerror when trying to get clipboard text: ", alloc_err)
				}
				assert(alloc_err == .None)

				textpkg.text_edit_insert(&state.state, text_to_paste)
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
process_interaction :: proc(
	interaction: ^Interaction,
	root_element: ^UI_Element,
	dt: f32,
	frame_allocator: mem.Allocator,
) {
	// find hits
	mouse_pos := interaction.input.mouse_pos
	hit_result := hit_test(root_element, mouse_pos)

	// update interaction ids, e.g. hot, pressed, focused
	update_interaction_ids(interaction, hit_result)

	dispatch_keyboard_to_focused(interaction, frame_allocator)

	apply_scroll(interaction, hit_result.scrollable)

	tween_animations(interaction, dt)
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
