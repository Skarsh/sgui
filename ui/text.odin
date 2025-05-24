package ui

import "core:log"
import "core:mem"
import "core:strings"
import "core:testing"

Word :: struct {
	start_offset: int,
	length:       int,
}

// TODO(Thomas): This needs to be done per character instead, to better deal with spaces and newlines
@(require_results)
measure_text_words :: proc(
	text: string,
	config: Text_Element_Config,
	allocator: mem.Allocator,
) -> []Word {
	words, alloc_err := make([dynamic]Word, allocator)
	assert(alloc_err == .None)

	if len(text) == 0 {
		return words[:]
	}

	splits: []string
	splits, alloc_err = strings.split(text, " ", allocator)
	assert(alloc_err == .None)

	idx := 0
	for split in splits {
		// The split is just a whitespace
		if len(split) == 0 {
			idx += 1
			continue
		}

		start := idx
		str_len := len(split)

		// Add 1 for the whitespace
		idx += str_len + 1
		append(&words, Word{start_offset = start, length = str_len})
	}

	return words[:]
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

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_no_white_space :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_start_with_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := " one"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 1, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_start_with_multiple_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "  one"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 2, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_single_word_ends_with_whitespace :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one "

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 0, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_two_words_single_white_space :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 0, length = 3}, {start_offset = 4, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_two_words_multiple_whitespace_between :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one  two"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

	expected_words := []Word{{start_offset = 0, length = 3}, {start_offset = 5, length = 3}}
	expect_words(t, words, expected_words)
}

@(test)
test_measure_words_many_words :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two three four five six seven eight nine ten"

	words := measure_text_words(
		text,
		Text_Element_Config{char_width = CHAR_WIDTH, char_height = CHAR_HEIGHT},
		allocator,
	)

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
