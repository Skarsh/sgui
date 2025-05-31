package ui

import "core:log"
import "core:mem"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

// Both start_offset and length are in the amount of runes
Word :: struct {
	start_offset: int,
	length:       int,
}

word_to_string :: proc(text: string, word: Word) -> (string, bool) {
	return strings.substring(text, word.start_offset, word.start_offset + word.length)
}

// TODO(Thomas): What about CRLF?
@(require_results)
measure_text_words :: proc(text: string, allocator: mem.Allocator) -> []Word {
	words, alloc_err := make([dynamic]Word, allocator)
	assert(alloc_err == .None)

	if len(text) == 0 {
		return words[:]
	}

	start := 0
	i := 0

	for r, idx in text {
		//ch := text[i]

		// Handle space
		if r == ' ' {
			if i > start {
				append(&words, Word{start_offset = start, length = i - start})
			}
			i += 1
			start = i
			continue
		}

		// Handle newline
		if r == '\n' {
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

make_and_push_line :: proc(
	lines: ^[dynamic]Text_Line,
	s: string,
	start: int,
	end: int,
	char_width: int,
	char_height: int,
) {
	line, ok := strings.substring(s, start, end)
	assert(ok)
	trimmed_line := strings.trim_left_space(line)
	rune_count := utf8.rune_count_in_string(trimmed_line)
	append(
		lines,
		Text_Line {
			text = trimmed_line,
			width = i32(rune_count * char_width),
			height = i32(char_height),
		},
	)
}

// TODO(Thomas): Deal with newlines
calculate_text_lines :: proc(
	text: string,
	words: []Word,
	config: Text_Element_Config,
	element_width: int,
	allocator: mem.Allocator,
) -> []Text_Line {
	lines := make([dynamic]Text_Line, allocator)

	char_width := config.char_width
	char_height := config.char_height
	min_width := config.min_width
	min_height := config.min_height

	space_left := element_width

	// Index of first word on current line
	beginning_line_word_idx := 0
	current_line_width := 0

	for word, idx in words {
		word_width := word.length * char_width
		space_width := char_width

		// Check if we need space before this word (not for first word on line)
		needs_whitespace := idx > beginning_line_word_idx
		width_with_word := current_line_width + (needs_whitespace ? space_width : 0) + word_width

		// We need to wrap onto a new line
		//if (word_width + space_width >= space_left) {
		if width_with_word > element_width && idx > beginning_line_word_idx {

			// Push the current line (from beginning_line_word_idx to current word exclusive)
			first_word := words[beginning_line_word_idx]
			last_word := words[idx - 1]
			line_start := first_word.start_offset
			line_end := last_word.start_offset + last_word.length

			make_and_push_line(&lines, text, line_start, line_end, char_width, char_height)

			// Start new line with current word
			beginning_line_word_idx = idx
			current_line_width = word_width
			space_left = element_width - word_width

		} else {
			// Add word to current line
			if needs_whitespace {
				current_line_width += space_width
			}
			current_line_width += word_width
			space_left = element_width - current_line_width
		}

		// Handle last word
		if idx == len(words) - 1 {
			first_word := words[beginning_line_word_idx]
			last_word := words[idx]
			line_start := first_word.start_offset
			line_end := last_word.start_offset + last_word.length

			make_and_push_line(&lines, text, line_start, line_end, char_width, char_height)
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

expect_lines :: proc(t: ^testing.T, lines: []Text_Line, expected_lines: []Text_Line) {
	testing.expect_value(t, len(lines), len(expected_lines))
	for line, idx in lines {
		testing.expect_value(t, line, expected_lines[idx])
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

@(test)
test_measure_words_multi_byte_character :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)
	text := "©"

	words := measure_text_words(text, allocator)

	expected_words := []Word{{start_offset = 0, length = 1}}
	expect_words(t, words, expected_words)
}

@(test)
test_calculate_text_lines_single_word :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one\n"

	words := measure_text_words(text, allocator)
	expected_words := []Word{{start_offset = 0, length = 3}}

	char_width := 10
	char_height := 10
	min_width := 100
	min_height := 10
	element_width := min_width
	expected_line_text := "one"
	expected_lines := []Text_Line {
		{
			text = expected_line_text,
			width = i32(char_width * utf8.rune_count_in_string(expected_line_text)),
			height = i32(char_height),
		},
	}

	lines := calculate_text_lines(
		text,
		words,
		Text_Element_Config {
			char_width = char_width,
			char_height = char_height,
			min_width = min_width,
			min_height = min_height,
		},
		element_width,
		allocator,
	)

	expect_lines(t, lines, expected_lines)
}

@(test)
test_calculate_text_lines_multiple_words :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two three\n"

	words := measure_text_words(text, allocator)

	char_width := 10
	char_height := 10
	min_width := 100
	min_height := 10
	element_width := min_width
	expected_lines := []Text_Line {
		{
			text = "one two",
			width = i32(char_width * utf8.rune_count_in_string("one two")),
			height = i32(char_height),
		},
		{
			text = "three",
			width = i32(char_width * utf8.rune_count_in_string("three")),
			height = i32(char_height),
		},
	}

	lines := calculate_text_lines(
		text,
		words,
		Text_Element_Config {
			char_width = char_width,
			char_height = char_height,
			min_width = min_width,
			min_height = min_height,
		},
		element_width,
		allocator,
	)

	expect_lines(t, lines, expected_lines)
}

@(test)
test_calculate_text_lines_two_lines_two_words_on_each :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two three four\n"

	words := measure_text_words(text, allocator)

	char_width := 10
	char_height := 10
	min_width := 100
	min_height := 10
	element_width := min_width
	expected_lines := []Text_Line {
		{
			text = "one two",
			width = i32(char_width * utf8.rune_count_in_string("one two")),
			height = i32(char_height),
		},
		{
			text = "three four",
			width = i32(char_width * utf8.rune_count_in_string("three four")),
			height = i32(char_height),
		},
	}

	lines := calculate_text_lines(
		text,
		words,
		Text_Element_Config {
			char_width = char_width,
			char_height = char_height,
			min_width = min_width,
			min_height = min_height,
		},
		element_width,
		allocator,
	)

	expect_lines(t, lines, expected_lines)
}

@(test)
test_calculate_text_lines_last_word_should_fit_on_current_line :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "one two three four five six"

	words := measure_text_words(text, allocator)

	char_width := 10
	char_height := 10
	min_width := 100
	min_height := 10
	element_width := 100
	expected_lines := []Text_Line {
		{
			text = "one two",
			width = i32(char_width * utf8.rune_count_in_string("one two")),
			height = i32(char_height),
		},
		{
			text = "three four",
			width = i32(char_width * utf8.rune_count_in_string("three four")),
			height = i32(char_height),
		},
		{
			text = "five six",
			width = i32(char_width * utf8.rune_count_in_string("five six")),
			height = i32(char_height),
		},
	}

	lines := calculate_text_lines(
		text,
		words,
		Text_Element_Config {
			char_width = char_width,
			char_height = char_height,
			min_width = min_width,
			min_height = min_height,
		},
		element_width,
		allocator,
	)

	expect_lines(t, lines, expected_lines)
}

@(test)
test_calculate_text_line_with_copyright_symbol :: proc(t: ^testing.T) {
	allocator := context.temp_allocator
	defer free_all(allocator)

	text := "© 2025 Dashboard System v1.0"

	words := measure_text_words(text, allocator)

	char_width := 10
	char_height := 10
	min_width := 100
	min_height := 10
	element_width := min_width

	expected_lines := []Text_Line {
		{
			text = "© 2025",
			width = i32(char_width * utf8.rune_count_in_string("© 2025")),
			height = i32(char_height),
		},
		{
			text = "Dashboard",
			width = i32(char_width * utf8.rune_count_in_string("Dashboard")),
			height = i32(char_height),
		},
		{
			text = "System",
			width = i32(char_width * utf8.rune_count_in_string("System")),
			height = i32(char_height),
		},
		{
			text = "v1.0",
			width = i32(char_width * utf8.rune_count_in_string("v1.0")),
			height = i32(char_height),
		},
	}

	lines := calculate_text_lines(
		text,
		words,
		Text_Element_Config {
			char_width = char_width,
			char_height = char_height,
			min_width = min_width,
			min_height = min_height,
		},
		element_width,
		allocator,
	)

	expect_lines(t, lines, expected_lines)
}
