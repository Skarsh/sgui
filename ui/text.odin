package ui

import "core:log"
import "core:mem"
import "core:strings"
import "core:testing"

Word :: struct {
	start_offset: int,
	length:       int,
}

@(require_results)
measure_text_words :: proc(text: string, allocator: mem.Allocator) -> []Word {
	words, alloc_err := make([dynamic]Word, allocator)
	assert(alloc_err == .None)

	if len(text) == 0 {
		return words[:]
	}

	start := 0
	i := 0

	for i < len(text) {
		ch := text[i]

		// Handle space
		if ch == ' ' {
			if i > start {
				append(&words, Word{start_offset = start, length = i - start})
			}
			i += 1
			start = i
			continue
		}

		// Handle newline
		if ch == '\n' {
			if i > start {
				append(&words, Word{start_offset = start, length = i - start})
			}
			i += 1
			start = i
			continue
		}

		i += 1
	}

	// This handles the cases: 
	// - There is no space or newline, just one continous word
	// - The final word after a space or newline
	if i > start {
		append(&words, Word{start_offset = start, length = i - start})
	}

	return words[:]
}

Text_Line :: struct {
	text:   string,
	width:  i32,
	height: i32,
}

calculate_text_lines :: proc(
	words: []Word,
	config: Text_Element_Config,
	allocator: mem.Allocator,
) -> []Text_Line {
	lines := make([dynamic]Text_Line, allocator)

	char_width := config.char_width
	char_height := config.char_height
	min_width := config.min_width
	min_height := config.min_height

	space_left := min_width

	for word, idx in words {
		word_width := word.length * char_width
		space_width := char_width
		if word_width + space_width > space_left {
		}
	}

	return lines[:]
}

expect_words :: proc(t: ^testing.T, words: []Word, expected_words: []Word) {
	testing.expect_value(t, len(words), len(expected_words))
	for word, idx in words {
		testing.expect_value(t, word, expected_words[idx])
	}
}

@(test)
test_measure_words_empty :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := ""

	words := measure_text_words(text, allocator)

	expected_words := []Word{}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_no_white_space :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_start_with_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := " one"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 1, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_start_with_multiple_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "  one"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 2, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_ends_with_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one "

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_two_words_single_white_space :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}, {start_offset = 4, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_two_words_multiple_whitespace_between :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one  two"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}, {start_offset = 5, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_many_words :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two three four five six seven eight nine ten"

	words := measure_text_words(text, allocator)

	expected_words := []Word {
		{start_offset = 0, length = 3}, // one
		{start_offset = 4, length = 3}, // two
		{start_offset = 8, length = 5}, // three
		{start_offset = 14, length = 4}, // four
		{start_offset = 19, length = 4}, // five
		{start_offset = 24, length = 3}, // six
		{start_offset = 28, length = 5}, // seven
		{start_offset = 34, length = 5}, // eight
		{start_offset = 40, length = 4}, // nine
		{start_offset = 45, length = 3}, // ten
	}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_only_newline :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "\n"

	words := measure_text_words(text, allocator)

	expected_words := []Word{}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_ends_with_newline :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one\n"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_ends_with_whitespace_before_newline :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one \n"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}
