package ui

import "core:container/queue"
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
	input:                ^base.Input,
	// text_measurement is owned by app
	text_measurement:     ^textpkg.Text_Measurement,
	text_input_states:    map[UI_Key]Text_Input_State,
	active_element:       ^UI_Element,
	interactive_elements: [dynamic]^UI_Element,
}

init_interaction :: proc(interaction: ^Interaction, allocator: mem.Allocator) {
	interaction.text_input_states = make(map[UI_Key]Text_Input_State, allocator)
	interaction.interactive_elements = make([dynamic]^UI_Element, allocator)
}

deinit_interaction :: proc(interaction: ^Interaction) {
	for key in interaction.text_input_states {
		state := &interaction.text_input_states[key]
		textpkg.text_buffer_deinit(&state.state.buffer)
	}
	delete(interaction.text_input_states)
}

// Traverses the element hierarchy in BFS order and appends on the elements
// that intersects with the given position.
find_intersections :: proc(
	root_element: ^UI_Element,
	pos: base.Vector2i32,
	elements: ^[dynamic]^UI_Element,
	allocator: mem.Allocator,
) {
	q := queue.Queue(^UI_Element){}
	queue.init(&q, allocator = allocator)
	visited := make(map[UI_Key]bool, allocator)

	visited[root_element.key] = true
	ok, alloc_err := queue.push_back(&q, root_element)
	if alloc_err != .None {
		log.errorf("failed to allocate when push_back onto queue: %v", alloc_err)
	}
	assert(ok)
	assert(alloc_err == .None)

	for queue.len(q) > 0 {
		v := queue.pop_front(&q)

		rect := base.Rect{i32(v.position.x), i32(v.position.y), i32(v.size.x), i32(v.size.y)}

		if base.point_in_rect(pos, rect) {
			append(elements, v)
		}

		for child in v.children {
			_, found := visited[child.key]
			if !found {
				visited[child.key] = true
				ok, alloc_err = queue.push_back(&q, child)

				if alloc_err != .None {
					log.errorf("failed to allocate when push_back onto queue: %v", alloc_err)
				}

				assert(alloc_err == .None)
				assert(ok)
			}
		}
	}
}

// TODO(Thomas): Should really aim for a more structured approach here. This is quite messy.
process_input :: proc(
	interaction: ^Interaction,
	root_element: ^UI_Element,
	dt: f32,
	allocator: mem.Allocator,
) {

	top_element: ^UI_Element
	intersecting_elements := make([dynamic]^UI_Element, allocator)
	find_intersections(
		root_element,
		interaction.input.mouse_pos,
		&intersecting_elements,
		allocator,
	)

	#reverse for elem in intersecting_elements {
		if .Clickable in elem.config.capability_flags {
			top_element = elem
			break
		}
	}

	{
		// Scrolling
		// TODO(Thomas): This should probably be per element
		SCROLL_SPEED: f32 : 30.0
		// TODO(Thomas): Combine this iteratiion with the one for the .Clickable?
		#reverse for elem in intersecting_elements {
			if .Scrollable in elem.config.capability_flags {
				if math.abs(interaction.input.scroll_delta.y) > 0 {
					offset_delta := f32(interaction.input.scroll_delta.y) * SCROLL_SPEED

					elem.scroll_region.target_offset.y -= offset_delta

					// NOTE(Thomas) Clamp immediately. This is necessary for input responsiveness.
					// Imagine the case where input goes to -1000, of not clamped to 0,
					// then scrolling in the positive direction will feel sluggish.
					elem.scroll_region.target_offset.y = math.clamp(
						elem.scroll_region.target_offset.y,
						0,
						elem.scroll_region.max_offset.y,
					)

					break
				}
			}
		}
	}


	// Update active element state
	// This is important to do before the processing
	{
		if interaction.active_element != nil {
			if base.is_mouse_pressed(interaction.input^, .Left) {
				is_on_active :=
					top_element != nil && top_element.key == interaction.active_element.key

				if !is_on_active {
					interaction.active_element = nil
				}
			}

			// If mouse released and element is not focusable, immediately lose active status
			if base.is_mouse_released(interaction.input^, .Left) {
				if .Focusable not_in interaction.active_element.config.capability_flags {
					interaction.active_element = nil
				}
			}
		}
	}


	// Iterate interactive elements
	for element in interaction.interactive_elements {

		comm := Comm {
			element = element,
		}

		is_top_element := (top_element != nil && top_element.key == element.key)
		is_active_element :=
			(interaction.active_element != nil && interaction.active_element.key == element.key)

		// Handle active element
		if is_active_element {

			if base.is_mouse_down(interaction.input^, .Left) {
				comm.held = true
			}

			// Text edit
			key := interaction.active_element.key
			state, state_ok := &interaction.text_input_states[key]

			if state_ok {
				if interaction.input.text_input.len > 0 {
					text := string(
						interaction.input.text_input.data[:interaction.input.text_input.len],
					)
					textpkg.text_edit_insert(&state.state, text)
				}

				keymod := interaction.input.keymod_down_bits
				keys := interaction.input.key_pressed_bits
				clipboard_command := textpkg.text_edit_handle_keys(&state.state, keys, keymod)

				switch clipboard_command {
				case .None:
				case .Copy:
					log.info("Copy clipboard command")
				case .Paste:
					log.info("Paste clipboard command")
				case .Cut:
					// TODO(Thomas): Does this really need to be its own thing?
					// Isn't this just a copy selection but where the selection is deleted / removed before return??
					log.info("Cut clipboard command")
				}
			}

		} else {
			if is_top_element {
				// Set new active element
				if base.is_mouse_pressed(interaction.input^, .Left) {
					if .Focusable in element.config.capability_flags {
						interaction.active_element = element
					}
					comm.clicked = true
					comm.held = true
					element.active = 1.0
				}
			}
		}

		// Processing for every element
		// Animations
		// TODO(Thomas): Animations should be styleable / configurable
		hot_animation_rate_of_change := (1.0 / 0.2) * dt
		active_animation_rate_of_change := hot_animation_rate_of_change

		// Handle hover state
		if is_top_element || is_active_element {
			element.hot += hot_animation_rate_of_change
			comm.hovering = true
		} else {
			element.hot -= hot_animation_rate_of_change
		}

		if !comm.held {
			element.active -= active_animation_rate_of_change
		}

		// Clamp animations and set final comm state
		element.hot = math.clamp(element.hot, 0, 1)

		if base.approx_equal(element.active, 1.0, 0.001) {
			comm.active = true
		}

		if base.approx_equal(element.hot, 1.0, 0.001) {
			comm.hot = true
		}

		element.last_comm = comm
	}
}
