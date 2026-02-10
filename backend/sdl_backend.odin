package backend

import sdl "vendor:sdl2"

import "../base"

sdl_get_perf_counter :: proc() -> u64 {
	return sdl.GetPerformanceCounter()
}

sdl_get_perf_freq :: proc() -> u64 {
	return sdl.GetPerformanceFrequency()
}

// Window API implementations
sdl_window_init :: proc() -> bool {
	return sdl.Init(sdl.INIT_VIDEO) >= 0
}

sdl_window_deinit :: proc() {
	sdl.Quit()
}

sdl_create_window :: proc(title: cstring, size: base.Vector2i32) -> (rawptr, bool) {
	window := sdl.CreateWindow(
		title,
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		size.x,
		size.y,
		{.SHOWN, .RESIZABLE, .OPENGL},
	)
	return rawptr(window), window != nil
}

sdl_destroy_window :: proc(handle: rawptr) {
	sdl.DestroyWindow(cast(^sdl.Window)handle)
}

sdl_create_gl_context :: proc(handle: rawptr) -> (rawptr, bool) {
	gl_context := sdl.GL_CreateContext(cast(^sdl.Window)handle)
	return rawptr(gl_context), gl_context != nil
}

sdl_make_gl_current :: proc(handle: rawptr, gl_context: rawptr) -> bool {
	return sdl.GL_MakeCurrent(cast(^sdl.Window)handle, cast(sdl.GLContext)gl_context) == 0
}

sdl_set_gl_attribute :: proc(attr: GL_Attribute, value: i32) -> bool {
	sdl_attr: sdl.GLattr
	switch attr {
	case .Context_Profile_Mask:
		sdl_attr = .CONTEXT_PROFILE_MASK
	case .Context_Major_Version:
		sdl_attr = .CONTEXT_MAJOR_VERSION
	case .Context_Minor_Version:
		sdl_attr = .CONTEXT_MINOR_VERSION
	}
	return sdl.GL_SetAttribute(sdl_attr, value) == 0
}

sdl_set_swap_interval :: proc(interval: i32) -> bool {
	return sdl.GL_SetSwapInterval(interval) == 0
}

sdl_swap_window :: proc(handle: rawptr) {
	sdl.GL_SwapWindow(cast(^sdl.Window)handle)
}

sdl_get_gl_proc_address :: proc() -> GL_Set_Proc_Address_Type {
	return sdl.gl_set_proc_address
}

create_sdl_window_api :: proc() -> Window_API {
	return Window_API {
		init = sdl_window_init,
		deinit = sdl_window_deinit,
		create_window = sdl_create_window,
		destroy_window = sdl_destroy_window,
		create_gl_context = sdl_create_gl_context,
		make_gl_current = sdl_make_gl_current,
		set_gl_attribute = sdl_set_gl_attribute,
		set_swap_interval = sdl_set_swap_interval,
		swap_window = sdl_swap_window,
		get_gl_proc_address = sdl_get_gl_proc_address,
	}
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

	if .LSHIFT in sdl_key_mod {
		key_mod += base.KMOD_LSHIFT
	}
	if .RSHIFT in sdl_key_mod {
		key_mod += base.KMOD_RSHIFT
	}
	if .LCTRL in sdl_key_mod {
		key_mod += base.KMOD_LCTRL
	}
	if .RCTRL in sdl_key_mod {
		key_mod += base.KMOD_RCTRL
	}
	if .LALT in sdl_key_mod {
		key_mod += base.KMOD_LALT
	}
	if .RALT in sdl_key_mod {
		key_mod += base.KMOD_RALT
	}
	if .LGUI in sdl_key_mod {
		key_mod += base.KMOD_LGUI
	}
	if .RGUI in sdl_key_mod {
		key_mod += base.KMOD_RGUI
	}
	if .NUM in sdl_key_mod {
		key_mod += base.KMOD_NUM
	}
	if .CAPS in sdl_key_mod {
		key_mod += base.KMOD_CAPS
	}
	if .MODE in sdl_key_mod {
		key_mod += base.KMOD_MODE
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
				valid = true
			}
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
