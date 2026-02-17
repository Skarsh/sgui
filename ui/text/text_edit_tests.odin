package text

import "core:testing"

@(test)
test_text_edit_move_left_collapsed_selection_moves_caret_left_by_one :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_move_to(&state, .Left)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_move_left_at_start_clamps_to_zero :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_move_to(&state, .Left)

	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_move_left_utf8_moves_by_rune_not_byte :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "a世b")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_move_to(&state, .Left)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}
