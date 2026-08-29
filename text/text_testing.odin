package text

import "core:testing"

import base "../base"
import gap_buffer "../gap_buffer"
import fixed_buffer "fixed_buffer"

Test_Backend :: enum {
	Gap,
	Fixed,
}

TEST_BACKENDS :: [?]Test_Backend{.Gap, .Fixed}

TEST_BUFFER_CAP :: 64

// Test only helper to make a Text_Buffer, getting initialized with the provided text.
@(private)
@(require_results)
test_text_buffer :: proc(backend: Test_Backend, capacity: int, text: string) -> Text_Buffer {
	tb: Text_Buffer
	switch backend {
	case .Gap:
		gb := gap_buffer.Gap_Buffer{}
		alloc_err := gap_buffer.init_gap_buffer(&gb, capacity, context.temp_allocator)
		assert(alloc_err == .None)
		insert_err := gap_buffer.insert_at(&gb, 0, text)
		assert(insert_err == .None)
		tb = Text_Buffer {
			buf = gb,
		}
	case .Fixed:
		storage, alloc_err := make([]u8, capacity, context.temp_allocator)
		assert(alloc_err == .None)
		fb := fixed_buffer.Fixed_Buffer{}
		fixed_buffer.init_with_content(&fb, storage, transmute([]u8)text)
		tb = Text_Buffer {
			buf = fb,
		}
	}

	return tb
}

// Test only helper which checks that replacing a range yields the expected text on every backend.
@(private)
check_replace :: proc(
	t: ^testing.T,
	initial: string,
	start, end: int,
	replacement: string,
	expected: string,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		tb := test_text_buffer(backend, buffer_capacity, initial)

		replace_err := text_buffer_replace_range(&tb, start, end, replacement)
		testing.expectf(
			t,
			replace_err == nil,
			"[%v] replacing [%v, %v) in %q with %q: expected success, got %v",
			backend,
			start,
			end,
			initial,
			replacement,
			replace_err,
			loc = loc,
		)

		actual, alloc_err := text_buffer_text(tb, context.temp_allocator)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual == expected,
			"[%v] replacing [%v, %v) in %q with %q: expected %q, got %q",
			backend,
			start,
			end,
			initial,
			replacement,
			expected,
			actual,
			loc = loc,
		)
	}
}

// Test only helper to make a Text_Buffer, getting initialized with the provided text and selection.
@(private)
@(require_results)
test_text_edit_state :: proc(
	backend: Test_Backend,
	buffer_capacity: int,
	text: string,
	selection: Selection,
) -> Text_State {
	text_edit_state := Text_Edit_State{}
	text_edit_init(&text_edit_state, test_text_buffer(backend, buffer_capacity, text))
	state := Text_State {
		selection = selection,
		variant   = text_edit_state,
	}

	return state
}

@(private)
@(require_results)
test_text_read_only_state :: proc(text: string, selection: Selection) -> Text_State {
	text_read_only_state := Text_Read_Only_State {
		text = text,
	}
	state := Text_State {
		selection = selection,
		variant   = text_read_only_state,
	}
	return state
}

// Test only helper which checks that moving at selection
// with translation yields expected selection on every backend.
@(private)
check_move :: proc(
	t: ^testing.T,
	text: string,
	selection: Selection,
	translation: Translation,
	expected_selection: Selection,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	// Text Edit asserts
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, buffer_capacity, text, selection)
		error := text_cursor_apply(&state, Cursor_Move{translation = translation})
		assert(error == nil)

		testing.expectf(
			t,
			state.selection == expected_selection,
			"[%v] move %v in %q from %v: expected %v, got %v",
			backend,
			translation,
			text,
			selection,
			expected_selection,
			state.selection,
			loc = loc,
		)
	}

	// Text_Read_Only asserts
	state := test_text_read_only_state(text, selection)
	error := text_cursor_apply(&state, Cursor_Move{translation = translation})
	assert(error == nil)
	testing.expectf(
		t,
		state.selection == expected_selection,
		"move %v in %q from %v: expected %v, got %v",
		translation,
		text,
		selection,
		expected_selection,
		state.selection,
		loc = loc,
	)
}

// Test only helper which checks that selecting at selection with translation
// yields expected selection on every backend.
@(private)
check_select :: proc(
	t: ^testing.T,
	text: string,
	selection: Selection,
	translation: Translation,
	expected_selection: Selection,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	// Text_Edit asserts
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, buffer_capacity, text, selection)
		text_cursor_move(&state, Cursor_Move{translation = translation, select = true})
		testing.expectf(
			t,
			state.selection == expected_selection,
			"[%v] select %v in %q from %v: expected %v, got %v",
			backend,
			translation,
			text,
			selection,
			expected_selection,
			state.selection,
			loc = loc,
		)
	}

	// Text_Read_Only asserts
	state := test_text_read_only_state(text, selection)
	error := text_cursor_apply(&state, Cursor_Move{translation = translation, select = true})
	assert(error == nil)
	testing.expectf(
		t,
		state.selection == expected_selection,
		"move %v in %q from %v: expected %v, got %v",
		translation,
		text,
		selection,
		expected_selection,
		state.selection,
		loc = loc,
	)
}

// Test only helper which checks that deleting at selection
// with translation yields expected text and expected selection on every backend.
@(private)
check_delete :: proc(
	t: ^testing.T,
	text: string,
	selection: Selection,
	translation: Translation,
	expected_text: string,
	expected_selection: Selection,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, buffer_capacity, text, selection)
		error := text_cursor_apply(&state, Cursor_Delete{translation = translation})
		assert(error == nil)

		actual_text, alloc_err := text_buffer_text(
			state.variant.(Text_Edit_State).buffer,
			context.temp_allocator,
		)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual_text == expected_text,
			"[%v] delete %v in %q from %v: expected text %q, got %q",
			backend,
			translation,
			text,
			selection,
			expected_text,
			actual_text,
			loc = loc,
		)
		testing.expectf(
			t,
			state.selection == expected_selection,
			"[%v] delete %v in %q from %v: expected selection %v, got %v",
			backend,
			translation,
			text,
			selection,
			expected_selection,
			state.selection,
			loc = loc,
		)
	}
}

// Test only helper which checks that inserting at selection yields
// expected text and selection on every backend.
@(private)
check_edit_insert :: proc(
	t: ^testing.T,
	text: string,
	selection: Selection,
	insertion: string,
	expected_text: string,
	expected_selection: Selection,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, buffer_capacity, text, selection)
		error := text_cursor_apply(&state, Cursor_Insert{text = insertion})
		assert(error == nil)

		actual_text, alloc_err := text_buffer_text(
			state.variant.(Text_Edit_State).buffer,
			context.temp_allocator,
		)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual_text == expected_text,
			"[%v] insert %q in %q at %v: expected text %q, got %q",
			backend,
			insertion,
			text,
			selection,
			expected_text,
			actual_text,
			loc = loc,
		)
		testing.expectf(
			t,
			state.selection == expected_selection,
			"[%v] insert %q in %q at %v: expected selection %v, got %v",
			backend,
			insertion,
			text,
			selection,
			expected_selection,
			state.selection,
			loc = loc,
		)
	}
}

// Test only helper which checks that keys get handled
// as expected as expected on every backend
@(private)
check_handle_keys :: proc(
	t: ^testing.T,
	text: string,
	selection: Selection,
	keys: base.Key_Set,
	mods: base.Keymod_Set,
	expected_text: string,
	expected_selection: Selection,
	buffer_capacity: int = TEST_BUFFER_CAP,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, buffer_capacity, text, selection)
		// TODO(Thomas): Should we use the return command here somehow?
		_, error := text_cursor_handle_keys(&state, keys, mods)
		assert(error == nil)

		actual_text, alloc_err := text_buffer_text(
			state.variant.(Text_Edit_State).buffer,
			context.temp_allocator,
		)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual_text == expected_text,
			"[%v] keys %v mods %v in %q at %v: expected text %q, got %q",
			backend,
			keys,
			mods,
			text,
			selection,
			expected_text,
			actual_text,
			loc = loc,
		)
		testing.expectf(
			t,
			state.selection == expected_selection,
			"[%v] keys %v mods %v in %q at %v: expected selection %v, got %v",
			backend,
			keys,
			mods,
			text,
			selection,
			expected_selection,
			state.selection,
			loc = loc,
		)
	}
}
