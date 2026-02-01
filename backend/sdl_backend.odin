package backend

import sdl "vendor:sdl2"

import "../base"

sdl_get_perf_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}

sdl_get_perf_freq :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}

sdl_key_to_ui_key :: proc(sdl_key: sdl.Keycode) -> base.Key {
	key := base.Key.Unknown
	// TODO(Thomas): Complete more of this switch
	#partial switch sdl_key {
	case .ESCAPE:
		key = base.Key.Escape
	case .TAB:
		key = base.Key.Tab
	case .RETURN:
		key = base.Key.Return
	case .UP:
		key = base.Key.Up
	case .DOWN:
		key = base.Key.Down
	case .LEFT:
		key = base.Key.Left
	case .RIGHT:
		key = base.Key.Right
	case .LSHIFT:
		key = base.Key.Left_Shift
	case .RSHIFT:
		key = base.Key.Right_Shift
	case .BACKSPACE:
		key = base.Key.Backspace
	}
	return key
}

sdl_keymod_to_ui_keymod :: proc(sdl_key_mod: sdl.Keymod) -> base.Keymod_Set {
	key_mod := base.KMOD_NONE

	// TODO(Thomas): Do this for the complete set of modifiers
	if .LSHIFT in sdl_key_mod {
		key_mod = base.KMOD_LSHIFT
	} else if .RSHIFT in sdl_key_mod {
		key_mod = base.KMOD_RSHIFT
	} else if .LSHIFT in sdl_key_mod && .RSHIFT in sdl_key_mod {
		key_mod = base.KMOD_SHIFT
	}

	return key_mod
}

sdl_poll_events :: proc(user_data: rawptr, on_event: proc(data: rawptr, event: base.Event)) {
	sdl_event: sdl.Event
	for sdl.PollEvent(&sdl_event) {
		event: base.Event
		valid := false

		#partial switch sdl_event.type {
		case .MOUSEMOTION:
			event = base.Mouse_Motion_Event {
				x = sdl_event.motion.x,
				y = sdl_event.motion.y,
			}
			valid = true
		case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP:
			btn: base.Mouse
			switch sdl_event.button.button {
			case sdl.BUTTON_LEFT:
				btn = .Left
			case sdl.BUTTON_RIGHT:
				btn = .Right
			case sdl.BUTTON_MIDDLE:
				btn = .Middle
			}
			event = base.Mouse_Button_Event {
				x      = sdl_event.button.x,
				y      = sdl_event.button.y,
				button = btn,
				down   = (sdl_event.type == .MOUSEBUTTONDOWN),
			}
			valid = true
		case .MOUSEWHEEL:
			event = base.Mouse_Wheel_Event {
				x = sdl_event.wheel.x,
				y = sdl_event.wheel.y,
			}
			valid = true
		case .KEYDOWN, .KEYUP:
			key := sdl_key_to_ui_key(sdl_event.key.keysym.sym)
			mod := sdl_keymod_to_ui_keymod(sdl_event.key.keysym.mod)
			event = base.Keyboard_Event {
				key  = key,
				mod  = mod,
				down = (sdl_event.type == .KEYDOWN),
			}
			valid = true
		// TODO(Thomas): Any possible non-copy solution here?
		// TODO(Thomas): This doesn't have the right lifetime
		// TODO(Thomas): Make sure we're dealing with cases of overflow properly
		case .TEXTINPUT:
			event = base.Text_Input_Event {
				text = sdl_event.text.text,
			}
			valid = true
		case .WINDOWEVENT:
			#partial switch sdl_event.window.event {
			case .SIZE_CHANGED:
				event = base.Window_Event {
					size_x = sdl_event.window.data1,
					size_y = sdl_event.window.data2,
				}
			}
			valid = true
		case .QUIT:
			// TODO(Thomas): What to do here?? Return bool? Callback?
			event = base.Quit_Event {
				quit = true,
			}
			valid = true
		}

		if valid {
			on_event(user_data, event)
		}
	}
}
