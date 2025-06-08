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

Word2 :: struct {
	start_offset: int,
	length:       int,
	width:        f32,
}

measure_string_width :: proc(ctx: ^Context, text: string, font_id: u16) -> f32 {
	assert(ctx.measure_text_proc != nil)
	if ctx.measure_text_proc != nil {
		metrics := ctx.measure_text_proc(text, font_id, ctx.font_user_data)
		return metrics.width
	} else {
		log.error("measure_text_proc is nil")
		return 0
	}
}

measure_string_line_height :: proc(ctx: ^Context, text: string, font_id: u16) -> f32 {
	assert(ctx.measure_text_proc != nil)
	if ctx.measure_text_proc != nil {
		metrics := ctx.measure_text_proc(text, font_id, ctx.font_user_data)
		return metrics.line_height
	} else {
		log.error("measure_text_proc is nil")
		return 0
	}
}

measure_glyph_width :: proc(ctx: ^Context, codepoint: rune, font_id: u16) -> f32 {
	assert(ctx.measure_glyph_proc != nil)
	if ctx.measure_glyph_proc != nil {
		metrics := ctx.measure_glyph_proc(codepoint, font_id, ctx.font_user_data)
		return metrics.width
	} else {
		log.error("measure_glyph_proc is nil")
		return 0
	}
}


word_to_string :: proc(text: string, word: Word2) -> (string, bool) {
	return strings.substring(text, word.start_offset, word.start_offset + word.length)
}

// TODO(Thomas): We're losing the \n information here now.
// Think about whether we should store an empty word signaling \n
// Or we should split things int paragraphs in the calculate_text_lines instead.
measure_text_words :: proc(
	ctx: ^Context,
	text: string,
	font_id: u16,
	allocator: mem.Allocator,
) -> []Word2 {
	words, alloc_err := make([dynamic]Word2, allocator)
	assert(alloc_err == .None)

	if len(text) == 0 {
		return words[:]
	}

	start := 0
	i := 0
	for r in text {
		if r == ' ' || r == '\n' {
			if i > start {
				// Measure the word
				word_text := text[start:i]
				word_width := measure_string_width(ctx, word_text, font_id)
				append(&words, Word2{start_offset = start, length = i - start, width = word_width})
			}
			start = i + 1
		}

		i += 1
	}

	if i > start {
		word_width := measure_string_width(ctx, text[start:i], font_id)
		append(&words, Word2{start_offset = start, length = i - start, width = word_width})
	}

	return words[:]
}

// TODO(Thomas): Handle newlines
calculate_text_lines :: proc(
	ctx: ^Context,
	text: string,
	words: []Word2,
	config: Text_Element_Config,
	element_width: f32,
	font_id: u16,
	font_size: f32,
	allocator: mem.Allocator,
) -> []Text_Line {
	lines, alloc_err := make([dynamic]Text_Line, allocator)
	assert(alloc_err == .None)

	min_width := config.min_width
	min_height := config.min_height

	first_word_on_line_idx := 0
	current_line_width: f32 = 0
	space_width := measure_glyph_width(ctx, ' ', font_id)

	for word, idx in words {
		word_width := word.width
		// Check if we need whitespace before this word (not for first word on line)
		needs_whitespace := idx > first_word_on_line_idx
		width_with_word := current_line_width + (needs_whitespace ? space_width : 0) + word_width

		// We need to wrap onto a new line
		if width_with_word >= element_width && idx > first_word_on_line_idx {
			// Push the current line (from first_word_on_line_idx to current word exclusive)
			first_word := words[first_word_on_line_idx]
			last_word := words[idx - 1]
			line_start := first_word.start_offset
			line_end := last_word.start_offset + last_word.length

			line_text, line_text_ok := strings.substring(text, line_start, line_end)
			assert(line_text_ok)
			make_and_push_line(
				&lines,
				text,
				line_start,
				line_end,
				current_line_width,
				measure_string_line_height(ctx, line_text, font_id),
			)

			// Start new line with current word
			first_word_on_line_idx = idx
			current_line_width = word.width
		} else {
			// Add word to current line
			if needs_whitespace {
				current_line_width += space_width
			}
			current_line_width += word_width
		}

		// Handle last word
		if idx == len(words) - 1 {
			first_word := words[first_word_on_line_idx]
			last_word := words[idx]
			line_start := first_word.start_offset
			line_end := last_word.start_offset + last_word.length

			line_text, line_text_ok := strings.substring(text, line_start, line_end)
			assert(line_text_ok)
			make_and_push_line(
				&lines,
				text,
				line_start,
				line_end,
				current_line_width,
				measure_string_line_height(ctx, line_text, font_id),
			)
		}
	}

	return lines[:]
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
	width: f32,
	line_height: f32,
) {
	line, ok := strings.substring(s, start, end)
	assert(ok)
	trimmed_line := strings.trim_left_space(line)
	rune_count := utf8.rune_count_in_string(trimmed_line)
	append(lines, Text_Line{text = trimmed_line, width = i32(width), height = i32(line_height)})
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
