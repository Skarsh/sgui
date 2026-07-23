package text

import "core:testing"

import base "../base"

// "hé<NBSP><SPACE>世界". The NBSP is written as an escape so that it survives
// editing tools that normalize unicode, it is invisible but has to stay a
// 2 byte non-space.
// h = 1 byte, é = 2 bytes, NBSP = 2 bytes, SPACE = 1, 世 = 3 bytes, 界 = 3 bytes
@(private = "file")
UTF8_SAMPLE :: "hé\u00a0 世界"
#assert(len(UTF8_SAMPLE) == 12)

@(test)
test_text_edit_move_to :: proc(t: ^testing.T) {
	// Left
	check_move(t, "abc", {active = 2, anchor = 2}, .Left, {active = 1, anchor = 1})
	check_move(t, "abc", {active = 0, anchor = 0}, .Left, {active = 0, anchor = 0})
	// a + 世 = 1 + 3 = 4 bytes
	check_move(t, "a世b", {active = 4, anchor = 4}, .Left, {active = 1, anchor = 1})
	check_move(t, "abcdef", {active = 5, anchor = 2}, .Left, {active = 2, anchor = 2})

	// Right
	check_move(t, "abc", {active = 1, anchor = 1}, .Right, {active = 2, anchor = 2})
	check_move(t, "abc", {active = 3, anchor = 3}, .Right, {active = 3, anchor = 3})
	// a + 世 = 1 + 3 = 4 bytes
	check_move(t, "a世b", {active = 1, anchor = 1}, .Right, {active = 4, anchor = 4})
	check_move(t, "abcdef", {active = 2, anchor = 5}, .Right, {active = 5, anchor = 5})

	// Next_Word
	check_move(t, "ab cd ef", {active = 0, anchor = 0}, .Next_Word, {active = 3, anchor = 3})
	check_move(t, "abc", {active = 3, anchor = 3}, .Next_Word, {active = 3, anchor = 3})

	// h + é + <NBSP> + <SPACE> = 1 + 2 + 2 + 1 = 6 bytes
	check_move(t, UTF8_SAMPLE, {active = 0, anchor = 0}, .Next_Word, {active = 6, anchor = 6})

	// Prev_Word
	check_move(t, "ab cd ef", {active = 8, anchor = 8}, .Prev_Word, {active = 6, anchor = 6})
	check_move(t, "ab cd ef", {active = 7, anchor = 7}, .Prev_Word, {active = 6, anchor = 6})
	check_move(t, "abc", {active = 0, anchor = 0}, .Prev_Word, {active = 0, anchor = 0})
	check_move(t, UTF8_SAMPLE, {active = 12, anchor = 12}, .Prev_Word, {active = 6, anchor = 6})
}

@(test)
test_text_edit_select_to :: proc(t: ^testing.T) {
	// Left
	check_select(t, "abc", {active = 2, anchor = 2}, .Left, {active = 1, anchor = 2})
	check_select(t, "abc", {active = 0, anchor = 0}, .Left, {active = 0, anchor = 0})

	// Right
	check_select(t, "abc", {active = 0, anchor = 0}, .Right, {active = 1, anchor = 0})
	check_select(t, "abc", {active = 3, anchor = 3}, .Right, {active = 3, anchor = 3})

	// Start
	check_select(t, "abc", {active = 2, anchor = 2}, .Start, {active = 0, anchor = 2})

	// End
	check_select(t, "abc", {active = 1, anchor = 1}, .End, {active = 3, anchor = 1})

	// Next_Word
	check_select(t, "ab cd ef", {active = 0, anchor = 0}, .Next_Word, {active = 3, anchor = 0})
	check_select(t, "abc", {active = 3, anchor = 3}, .Next_Word, {active = 3, anchor = 3})

	// Prev_Word
	check_select(t, "ab cd ef", {active = 8, anchor = 8}, .Prev_Word, {active = 6, anchor = 8})
	check_select(t, "abc", {active = 0, anchor = 0}, .Prev_Word, {active = 0, anchor = 0})
}

@(test)
test_text_edit_delete_to :: proc(t: ^testing.T) {
	// Left
	check_delete(t, "abc", {active = 2, anchor = 2}, .Left, "ac", {active = 1, anchor = 1})
	check_delete(t, "abc", {active = 0, anchor = 0}, .Left, "abc", {active = 0, anchor = 0})

	// Right
	check_delete(t, "abc", {active = 1, anchor = 1}, .Right, "ac", {active = 1, anchor = 1})
	check_delete(t, "abcdef", {active = 4, anchor = 1}, .Right, "aef", {active = 1, anchor = 1})
	check_delete(t, "abc", {active = 3, anchor = 3}, .Right, "abc", {active = 3, anchor = 3})

	// Next_Word
	check_delete(
		t,
		"ab cd ef",
		{active = 0, anchor = 0},
		.Next_Word,
		"cd ef",
		{active = 0, anchor = 0},
	)

	check_delete(
		t,
		"ab cd ef",
		{active = 6, anchor = 6},
		.Next_Word,
		"ab cd ",
		{active = 6, anchor = 6},
	)

	check_delete(
		t,
		"ab cd",
		{active = 5, anchor = 5},
		.Next_Word,
		"ab cd",
		{active = 5, anchor = 5},
	)

	// Prev_Word
	check_delete(
		t,
		"ab cd ef",
		{active = 2, anchor = 2},
		.Prev_Word,
		" cd ef",
		{active = 0, anchor = 0},
	)

	check_delete(
		t,
		"ab cd ef",
		{active = 8, anchor = 8},
		.Prev_Word,
		"ab cd ",
		{active = 6, anchor = 6},
	)

	check_delete(
		t,
		"ab cd",
		{active = 0, anchor = 0},
		.Prev_Word,
		"ab cd",
		{active = 0, anchor = 0},
	)
}

@(test)
test_text_edit_insert :: proc(t: ^testing.T) {
	check_edit_insert(t, "abc", {active = 1, anchor = 1}, "XY", "aXYbc", {active = 3, anchor = 3})
	check_edit_insert(t, "abcdef", {active = 4, anchor = 1}, "Z", "aZef", {active = 2, anchor = 2})

	// 世 = 3 bytes, x = 1 byte, 3 + 1 = 4 bytes
	check_edit_insert(
		t,
		"abcdef",
		{active = 1, anchor = 4},
		"世x",
		"a世xef",
		{active = 5, anchor = 5},
	)
}

@(test)
test_text_edit_handle_keys :: proc(t: ^testing.T) {
	// Left
	check_handle_keys(
		t,
		"abc",
		{active = 2, anchor = 2},
		{.Left},
		base.KMOD_NONE,
		"abc",
		{active = 1, anchor = 1},
	)

	check_handle_keys(
		t,
		"abc",
		{active = 2, anchor = 2},
		{.Left},
		base.KMOD_SHIFT,
		"abc",
		{active = 1, anchor = 2},
	)

	check_handle_keys(
		t,
		"ab cd ef",
		{active = 8, anchor = 8},
		{.Left},
		base.KMOD_CTRL,
		"ab cd ef",
		{active = 6, anchor = 6},
	)

	// Right
	check_handle_keys(
		t,
		"ab cd ef",
		{active = 0, anchor = 0},
		{.Right},
		base.KMOD_CTRL + base.KMOD_SHIFT,
		"ab cd ef",
		{active = 3, anchor = 0},
	)

	// Backspace
	check_handle_keys(
		t,
		"abc",
		{active = 2, anchor = 2},
		{.Backspace},
		base.KMOD_NONE,
		"ac",
		{active = 1, anchor = 1},
	)

	check_handle_keys(
		t,
		"ab cd ef",
		{active = 6, anchor = 6},
		{.Backspace},
		base.KMOD_CTRL,
		"ab ef",
		{active = 3, anchor = 3},
	)

	// A
	check_handle_keys(
		t,
		"ab cd ef",
		{active = 4, anchor = 4},
		{.A},
		base.KMOD_CTRL,
		"ab cd ef",
		{active = 8, anchor = 0},
	)

	// Home
	check_handle_keys(
		t,
		"abc",
		{active = 2, anchor = 2},
		{.Home},
		base.KMOD_NONE,
		"abc",
		{active = 0, anchor = 0},
	)

	check_handle_keys(
		t,
		"abc",
		{active = 2, anchor = 2},
		{.Home},
		base.KMOD_SHIFT,
		"abc",
		{active = 0, anchor = 2},
	)

	// End
	check_handle_keys(
		t,
		"abc",
		{active = 1, anchor = 1},
		{.End},
		base.KMOD_NONE,
		"abc",
		{active = 3, anchor = 3},
	)

	check_handle_keys(
		t,
		"abc",
		{active = 1, anchor = 1},
		{.End},
		base.KMOD_SHIFT,
		"abc",
		{active = 3, anchor = 1},
	)

	// Delete
	check_handle_keys(
		t,
		"abc",
		{active = 1, anchor = 1},
		{.Delete},
		base.KMOD_NONE,
		"ac",
		{active = 1, anchor = 1},
	)

	check_handle_keys(
		t,
		"ab cd ef",
		{active = 0, anchor = 0},
		{.Delete},
		base.KMOD_CTRL,
		"cd ef",
		{active = 0, anchor = 0},
	)

	// Tab
	check_handle_keys(
		t,
		"ab",
		{active = 1, anchor = 1},
		{.Tab},
		base.KMOD_NONE,
		"a\tb",
		{active = 2, anchor = 2},
	)
}
