package text

import "core:testing"
import "../../base"

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

@(test)
test_text_edit_move_right_collapsed_selection_moves_caret_right_by_one :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 1,
		anchor = 1,
	}

	text_edit_move_to(&state, .Right)

	testing.expect_value(t, state.selection.active, 2)
	testing.expect_value(t, state.selection.anchor, 2)
}

@(test)
test_text_edit_move_right_at_end_clamps_to_buffer_len :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 3,
		anchor = 3,
	}

	text_edit_move_to(&state, .Right)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_move_right_utf8_moves_by_rune_not_byte :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "a世b")
	state.selection = Selection {
		active = 1,
		anchor = 1,
	}

	text_edit_move_to(&state, .Right)

	testing.expect_value(t, state.selection.active, 2)
	testing.expect_value(t, state.selection.anchor, 2)
}

@(test)
test_text_edit_move_next_word_moves_to_start_of_next_word :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_move_to(&state, .Next_Word)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_move_next_word_at_end_clamps_to_buffer_len :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 3,
		anchor = 3,
	}

	text_edit_move_to(&state, .Next_Word)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_move_next_word_utf8_and_unicode_whitespace :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	// "hé<NBSP><SPACE>世界"
	text_buffer_insert_at(&state.buffer, 0, "hé  世界")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_move_to(&state, .Next_Word)

	testing.expect_value(t, state.selection.active, 4)
	testing.expect_value(t, state.selection.anchor, 4)
}

@(test)
test_text_edit_move_prev_word_moves_to_start_of_previous_word :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 8,
		anchor = 8,
	}

	text_edit_move_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 6)
	testing.expect_value(t, state.selection.anchor, 6)
}

@(test)
test_text_edit_move_prev_word_at_start_clamps_to_zero :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_move_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_move_prev_word_utf8_and_unicode_whitespace :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	// "hé<NBSP><SPACE>世界"
	text_buffer_insert_at(&state.buffer, 0, "hé  世界")
	state.selection = Selection {
		active = 6,
		anchor = 6,
	}

	text_edit_move_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 4)
	testing.expect_value(t, state.selection.anchor, 4)
}

@(test)
test_text_edit_move_prev_word_from_inside_word_moves_to_that_word_start :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 7,
		anchor = 7,
	}

	text_edit_move_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 6)
	testing.expect_value(t, state.selection.anchor, 6)
}

@(test)
test_text_edit_select_left_from_collapsed_caret_extends_selection_left :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_select_to(&state, .Left)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 2)
}

@(test)
test_text_edit_select_right_from_collapsed_caret_extends_selection_right :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_select_to(&state, .Right)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_select_next_word_from_collapsed_caret_extends_selection_to_next_word_start :: proc(
	t: ^testing.T,
) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_select_to(&state, .Next_Word)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_select_prev_word_from_collapsed_caret_extends_selection_to_prev_word_start :: proc(
	t: ^testing.T,
) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 8,
		anchor = 8,
	}

	text_edit_select_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 6)
	testing.expect_value(t, state.selection.anchor, 8)
}

@(test)
test_text_edit_select_start_from_collapsed_caret_extends_selection_to_start :: proc(
	t: ^testing.T,
) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_select_to(&state, .Start)

	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 2)
}

@(test)
test_text_edit_select_end_from_collapsed_caret_extends_selection_to_end :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 1,
		anchor = 1,
	}

	text_edit_select_to(&state, .End)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_select_left_at_start_clamps_to_zero :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_select_to(&state, .Left)

	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_select_right_at_end_clamps_to_buffer_len :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 3,
		anchor = 3,
	}

	text_edit_select_to(&state, .Right)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_select_next_word_at_end_clamps_to_buffer_len :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 3,
		anchor = 3,
	}

	text_edit_select_to(&state, .Next_Word)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_select_prev_word_at_start_clamps_to_zero :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_select_to(&state, .Prev_Word)

	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_delete_left_from_collapsed_caret_deletes_rune_before_caret :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_delete_to(&state, .Left)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ac")
	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_delete_right_from_collapsed_caret_deletes_rune_after_caret :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 1,
		anchor = 1,
	}

	text_edit_delete_to(&state, .Right)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ac")
	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_delete_next_word_from_collapsed_caret_deletes_to_next_word_start :: proc(
	t: ^testing.T,
) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_delete_to(&state, .Next_Word)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "cd ef")
	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_delete_to_with_non_collapsed_selection_deletes_selection_range :: proc(
	t: ^testing.T,
) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abcdef")
	state.selection = Selection {
		active = 4,
		anchor = 1,
	}

	text_edit_delete_to(&state, .Right)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "aef")
	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_delete_left_at_start_is_no_op :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_delete_to(&state, .Left)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "abc")
	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_delete_right_at_end_is_no_op :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 3,
		anchor = 3,
	}

	text_edit_delete_to(&state, .Right)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "abc")
	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}

@(test)
test_text_edit_delete_prev_word_at_start_is_no_op :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_delete_to(&state, .Prev_Word)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ab cd")
	testing.expect_value(t, state.selection.active, 0)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_delete_next_word_at_end_is_no_op :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd")
	state.selection = Selection {
		active = 5,
		anchor = 5,
	}

	text_edit_delete_to(&state, .Next_Word)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ab cd")
	testing.expect_value(t, state.selection.active, 5)
	testing.expect_value(t, state.selection.anchor, 5)
}

@(test)
test_text_edit_handle_key_left_without_mod_moves_caret_left :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_handle_key(&state, .Left)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_handle_key_shift_left_extends_selection_left :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_handle_key(&state, .Left, base.KMOD_SHIFT)

	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 2)
}

@(test)
test_text_edit_handle_key_ctrl_left_moves_to_prev_word :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 7,
		anchor = 7,
	}

	text_edit_handle_key(&state, .Left, base.KMOD_CTRL)

	testing.expect_value(t, state.selection.active, 6)
	testing.expect_value(t, state.selection.anchor, 6)
}

@(test)
test_text_edit_handle_key_ctrl_shift_right_extends_selection_to_next_word :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 0,
		anchor = 0,
	}

	text_edit_handle_key(&state, .Right, base.KMOD_CTRL + base.KMOD_SHIFT)

	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 0)
}

@(test)
test_text_edit_handle_key_backspace_deletes_left :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "abc")
	state.selection = Selection {
		active = 2,
		anchor = 2,
	}

	text_edit_handle_key(&state, .Backspace)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ac")
	testing.expect_value(t, state.selection.active, 1)
	testing.expect_value(t, state.selection.anchor, 1)
}

@(test)
test_text_edit_handle_key_ctrl_backspace_deletes_prev_word :: proc(t: ^testing.T) {
	state := text_edit_init(context.allocator)
	defer text_buffer_deinit(&state.buffer)

	text_buffer_insert_at(&state.buffer, 0, "ab cd ef")
	state.selection = Selection {
		active = 6,
		anchor = 6,
	}

	text_edit_handle_key(&state, .Backspace, base.KMOD_CTRL)

	actual := text_buffer_text(state.buffer)
	defer delete(actual)

	testing.expect_value(t, actual, "ab ef")
	testing.expect_value(t, state.selection.active, 3)
	testing.expect_value(t, state.selection.anchor, 3)
}
