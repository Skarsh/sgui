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
test_text_buffer :: proc(backend: Test_Backend, text: string) -> Text_Buffer {
	tb: Text_Buffer
	switch backend {
	case .Gap:
		gb := gap_buffer.Gap_Buffer{}
		alloc_err := gap_buffer.init_gap_buffer(&gb, TEST_BUFFER_CAP, context.temp_allocator)
		assert(alloc_err == .None)
		tb = Text_Buffer {
			buf = gb,
		}
	case .Fixed:
		storage, alloc_err := make([]u8, TEST_BUFFER_CAP, context.temp_allocator)
		assert(alloc_err == .None)
		tb = Text_Buffer {
			buf = fixed_buffer.Fixed_Buffer{buf = storage},
		}
	}

	insert_err := text_buffer_insert_at(&tb, 0, text)
	assert(insert_err == nil)

	return tb
}

// Test only helper which checks that inserting into initial at pos yields expected on every backend.
@(private)
check_insert :: proc(
	t: ^testing.T,
	initial: string,
	pos: int,
	insertion: string,
	expected: string,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		tb := test_text_buffer(backend, initial)

		insert_err := text_buffer_insert_at(&tb, pos, insertion)
		testing.expectf(
			t,
			insert_err == nil,
			"[%v] inserting %q at %v into %q: expected success, got %v",
			backend,
			insertion,
			pos,
			initial,
			insert_err,
			loc = loc,
		)

		actual, alloc_err := text_buffer_text(tb, context.temp_allocator)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual == expected,
			"[%v] inserting %q at %v into %q: expected %q, got %q",
			backend,
			insertion,
			pos,
			initial,
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
	text: string,
	selection: Selection,
) -> Text_Edit_State {
	state := Text_Edit_State{}
	text_edit_init(&state, test_text_buffer(backend, text))
	state.selection = selection
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
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, text, selection)
		text_edit_move_to(&state, translation)
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
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, text, selection)
		text_edit_select_to(&state, translation)
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
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, text, selection)
		text_edit_delete_to(&state, translation)

		actual_text, alloc_err := text_buffer_text(state.buffer, context.temp_allocator)
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
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, text, selection)
		text_buff_err := text_edit_insert(&state, insertion)
		assert(text_buff_err == nil)

		actual_text, alloc_err := text_buffer_text(state.buffer, context.temp_allocator)
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
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		state := test_text_edit_state(backend, text, selection)

		// TODO(Thomas): Should we use the return command here somehow?
		_, text_buffer_error := text_edit_handle_keys(&state, keys, mods)
		assert(text_buffer_error == nil)

		actual_text, alloc_err := text_buffer_text(state.buffer, context.temp_allocator)
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
