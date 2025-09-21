package ui

import "core:log"
import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

import base "../base"

Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Token :: struct {
	start:  int, // Byte start in original string
	length: int, // Length of the token in bytes
	width:  f32, // Measured width
	kind:   Token_Kind,
}

token_to_string :: proc(text: string, token: Text_Token) -> string {
	str, ok := strings.substring(text, token.start, token.start + token.length)
	assert(ok)
	return str
}

Text_Line :: struct {
	text:   string,
	start:  int, // Starting token idx
	length: int, // Length in number of tokens
	width:  f32, // Visual width
	height: f32, // Line height
}

tokenize_text :: proc(ctx: ^Context, text: string, font_id: u16, tokens: ^[dynamic]Text_Token) {
	if len(text) == 0 {
		return
	}

	rune_pos := 0
	start_pos := 0
	rune_count := strings.rune_count(text)
	for rune_pos < rune_count {
		start_pos = rune_pos
		r := utf8.rune_at_pos(text, rune_pos)
		if r == '\n' {
			rune_pos += 1
			length := rune_pos - start_pos
			append(
				tokens,
				Text_Token{start = start_pos, length = length, width = 0, kind = .Newline},
			)
		} else if unicode.is_space(r) {
			// Continue to eat whitespace until we've hit something that's not a whitespace rune
			for rune_pos < rune_count {
				peek_r := utf8.rune_at_pos(text, rune_pos)
				if peek_r != '\n' && unicode.is_space(peek_r) {
					rune_pos += 1
				} else {
					break
				}
			}

			length := rune_pos - start_pos

			// TODO(Thomas): What to do with '\t' when it comes to measuring string width here?
			token_str, ok := strings.substring(text, start_pos, rune_pos)
			assert(ok)
			width := measure_string_width(ctx, token_str, font_id)

			append(
				tokens,
				Text_Token{start = start_pos, length = length, width = width, kind = .Whitespace},
			)
		} else {
			// We accumulate all other runes that are not newline or whitespace into words
			for rune_pos < rune_count {
				peek_r := utf8.rune_at_pos(text, rune_pos)
				if !unicode.is_space(peek_r) {
					rune_pos += 1
				} else {
					break
				}
			}

			length := rune_pos - start_pos

			token_str, ok := strings.substring(text, start_pos, rune_pos)
			assert(ok)
			width := measure_string_width(ctx, token_str, font_id)
			append(
				tokens,
				Text_Token{start = start_pos, length = length, width = width, kind = .Word},
			)
		}
	}
}

get_text_from_tokens :: proc(
	text: string,
	start_token: Text_Token,
	end_token: Text_Token,
) -> string {
	start := start_token.start
	end := end_token.start + end_token.length
	str, ok := strings.substring(text, start, end)
	assert(ok)
	return str
}

Line_State :: struct {
	word_count:      int,
	start_token_idx: int,
	end_token_idx:   int,
	width:           f32,
}

flush_line :: proc(
	ctx: ^Context,
	original_text: string,
	tokens: []Text_Token,
	lines: ^[dynamic]Text_Line,
) {
	start_word_idx := 0
	end_word_idx := 0
	found_non_whitespace := false

	// Find first word token
	for token, i in tokens {
		if token.kind != .Whitespace {
			start_word_idx = i
			found_non_whitespace = true
			break
		}
	}

	// Find last word token
	#reverse for token, i in tokens {
		if token.kind != .Whitespace {
			end_word_idx = i
			found_non_whitespace = true
			break
		}
	}

	// If we found no word, that means that the line only contains
	// whitespace, which is not valid.
	if found_non_whitespace == false {
		return
	}

	// Trim beginning and trailing whitespace by slicing
	trimmed_tokens := tokens[start_word_idx:end_word_idx + 1]

	// Calculate the line width
	line_width: f32 = 0
	for token in trimmed_tokens {
		line_width += token.width
	}

	start_token := trimmed_tokens[0]
	end_token := trimmed_tokens[len(trimmed_tokens) - 1]
	line_text := get_text_from_tokens(original_text, start_token, end_token)

	line_height: f32
	if base.approx_equal(line_width, 0, 0.001) {
		// This is a empty line, made from two consecutive newlines
		// TODO(Thomas): Just using "A" as the height of the empty line
		// here. Is there a better approach? At least we don't have to
		// calculate this every time, this could be cached for the font_id
		// and font size.
		line_height = measure_string_line_height(ctx, "A", ctx.font_id)
	} else {
		line_height = measure_string_line_height(ctx, line_text, ctx.font_id)
	}

	line := Text_Line {
		text   = line_text,
		start  = start_token.start,
		length = (end_token.start + end_token.length) - start_token.start,
		width  = line_width,
		height = line_height,
	}


	append(lines, line)
}

layout_lines :: proc(
	ctx: ^Context,
	text: string,
	tokens: []Text_Token,
	available_width: f32,
	lines: ^[dynamic]Text_Line,
) {

	// NOTE(Thomas): We use a epsilon when comparing to the max_width (which is the element width)
	// This is necessary because for growing elements like text, the size we calculate here
	// and the size it gets in the grow layout calculations will be very similar. So we add
	// a epsilon to the max_width to make sure that if some text would fit on one line it will
	// and numerical instability won't be an issue.
	EPSILON :: 0.001

	// TODO(Thomas): Use an arena allocator here that's passed in instead.
	line_tokens := make([dynamic]Text_Token)
	defer delete(line_tokens)

	line_width: f32 = 0

	for token in tokens {
		switch token.kind {
		case .Newline:
			append(&line_tokens, token)
			flush_line(ctx, text, line_tokens[:], lines)
			clear_dynamic_array(&line_tokens)
			line_width = 0
		case .Whitespace, .Word:
			if line_width + token.width > available_width + EPSILON {
				flush_line(ctx, text, line_tokens[:], lines)
				clear_dynamic_array(&line_tokens)
				append(&line_tokens, token)
				line_width = token.width
			} else {
				append(&line_tokens, token)
				line_width += token.width
			}
		}
	}

	if line_width > 0 {
		flush_line(ctx, text, line_tokens[:], lines)
	}
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

expect_lines :: proc(t: ^testing.T, lines: []Text_Line, expected_lines: []Text_Line) {
	testing.expect_value(t, len(lines), len(expected_lines))
	for line, idx in lines {
		testing.expect_value(t, line, expected_lines[idx])
	}
}

expect_tokens :: proc(t: ^testing.T, tokens: []Text_Token, expected_tokens: []Text_Token) {
	testing.expect_value(t, len(tokens), len(expected_tokens))
	for token, idx in tokens {
		testing.expect_value(t, token, expected_tokens[idx])
	}
}

MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10

mock_measure_text_proc :: proc(text: string, font_id: u16, user_data: rawptr) -> Text_Metrics {
	width: f32 = f32(strings.rune_count(text) * MOCK_CHAR_WIDTH)
	line_height: f32 = MOCK_LINE_HEIGHT

	return Text_Metrics{width = width, line_height = line_height}
}

mock_measure_glyph_proc :: proc(
	codepoint: rune,
	font_id: u16,
	user_data: rawptr,
) -> Glyph_Metrics {
	width: f32 = MOCK_CHAR_WIDTH
	left_bearing: f32 = MOCK_CHAR_WIDTH
	return Glyph_Metrics{width = width, left_bearing = left_bearing}
}

// ------------ TESTS -------------

@(test)
test_token_in_middle :: proc(t: ^testing.T) {
	text := "Hello, wonderful world!"
	token := Text_Token {
		start  = 7,
		length = 9,
		width  = 0,
		kind   = .Word,
	}
	expected := "wonderful"
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_token_at_start :: proc(t: ^testing.T) {
	text := "Odin is a great language."
	token := Text_Token {
		start  = 0,
		length = 4,
		width  = 0,
		kind   = .Word,
	}
	expected := "Odin"
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_token_at_end :: proc(t: ^testing.T) {
	text := "Programming is fun."
	token := Text_Token {
		start  = 15,
		length = 4,
		width  = 0,
		kind   = .Word,
	}
	expected := "fun."
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_token_is_entire_string :: proc(t: ^testing.T) {
	text := "Complete"
	token := Text_Token {
		start  = 0,
		length = 8,
		width  = 0,
		kind   = .Word,
	}
	expected := "Complete"
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_zero_length_token :: proc(t: ^testing.T) {
	text := "An empty token"
	token := Text_Token {
		start  = 3,
		length = 0,
		width  = 0,
		kind   = .Whitespace,
	}
	expected := ""
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_single_character_token :: proc(t: ^testing.T) {
	text := "1"
	token := Text_Token {
		start  = 0,
		length = 1,
		width  = 0,
		kind   = .Word,
	}
	expected := "1"
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_single_whitespace_token :: proc(t: ^testing.T) {
	text := " "
	token := Text_Token {
		start  = 0,
		length = 1,
		width  = 0,
		kind   = .Whitespace,
	}
	expected := " "
	actual := token_to_string(text, token)
	testing.expect_value(t, actual, expected)
}

@(test)
test_tokenize_text :: proc(t: ^testing.T) {
	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 0, kind = .Newline},
	}
	expect_tokens(t, tokens[:], expected_tokens)

}

@(test)
test_tokenize_text_word_after_newline :: proc(t: ^testing.T) {
	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello\nWorld"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 0, kind = .Newline},
		Text_Token{start = 6, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_unicode_glyph :: proc(t: ^testing.T) {
	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "©"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_layout_lines_single_word_no_newline :: proc(t: ^testing.T) {
	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hello",
			start = 0,
			length = 5,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_single_word_and_newline :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 0, kind = .Newline},
	}
	expect_tokens(t, tokens[:], expected_tokens)


	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hello\n",
			start = 0,
			length = 6,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_word_after_newline :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello\nWorld"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 0, kind = .Newline},
		Text_Token{start = 6, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)


	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hello\n",
			start = 0,
			length = 6,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
		Text_Line {
			text = "World",
			start = 6,
			length = 5,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_two_word_no_overflow :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hel lo"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 3, width = 3 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 3, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Whitespace},
		Text_Token{start = 4, length = 2, width = 2 * MOCK_CHAR_WIDTH, kind = .Word},
	}

	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hel lo",
			start = 0,
			length = 6,
			width = 6 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_two_word_overflowing_ends_with_newline :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello world\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Whitespace},
		Text_Token{start = 6, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 11, length = 1, width = 0, kind = .Newline},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hello",
			start = 0,
			length = 5,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
		Text_Line {
			text = "world\n",
			start = 6,
			length = 6,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_two_words_with_newline_and_whitespace_inbetween :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Hello\n world\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 5, length = 1, width = 0, kind = .Newline},
		Text_Token{start = 6, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Whitespace},
		Text_Token{start = 7, length = 5, width = 5 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 12, length = 1, width = 0, kind = .Newline},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Hello\n",
			start = 0,
			length = 6,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
		Text_Line {
			text = "world\n",
			start = 7,
			length = 6,
			width = 5 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_one_word_matches_max_width_exact :: proc(t: ^testing.T) {
	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "0123456789"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 10, width = 10 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], 100, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "0123456789",
			start = 0,
			length = 10,
			width = 10 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_single_word_overflows_max_width :: proc(t: ^testing.T) {

	ctx := Context{}

	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "01234567890"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)


	max_width: f32 = 100
	expected_length := 11
	expected_width: f32 = f32(expected_length * MOCK_CHAR_WIDTH)

	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = expected_length, width = expected_width, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], max_width, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = text,
			start = 0,
			length = expected_length,
			width = expected_width,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)

}

@(test)
test_layout_lines_two_words_splits_on_whitespace :: proc(t: ^testing.T) {
	ctx := Context{}
	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "Button 1"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)

	max_width: f32 = 70

	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 6, width = 6 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 6, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Whitespace},
		Text_Token{start = 7, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Word},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], max_width, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "Button",
			start = 0,
			length = 6,
			width = 6 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
		Text_Line {
			text = "1",
			start = 7,
			length = 1,
			width = 1 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
	}

	expect_lines(t, lines[:], expected_lines)
}

@(test)
test_layout_lines_multiple_consecutive_newlines :: proc(t: ^testing.T) {
	ctx := Context{}
	set_text_measurement_callbacks(&ctx, mock_measure_text_proc, mock_measure_glyph_proc, nil)

	text := "A line\n\n\n"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(&ctx, text, 0, &tokens)
	max_width: f32 = 60

	expected_tokens := []Text_Token {
		Text_Token{start = 0, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 1, length = 1, width = 1 * MOCK_CHAR_WIDTH, kind = .Whitespace},
		Text_Token{start = 2, length = 4, width = 4 * MOCK_CHAR_WIDTH, kind = .Word},
		Text_Token{start = 6, length = 1, width = 0, kind = .Newline},
		Text_Token{start = 7, length = 1, width = 0, kind = .Newline},
		Text_Token{start = 8, length = 1, width = 0, kind = .Newline},
	}
	expect_tokens(t, tokens[:], expected_tokens)

	lines := make([dynamic]Text_Line, context.temp_allocator)
	layout_lines(&ctx, text, tokens[:], max_width, &lines)

	expected_lines := []Text_Line {
		Text_Line {
			text = "A line\n",
			start = 0,
			length = 7,
			width = 6 * MOCK_CHAR_WIDTH,
			height = MOCK_LINE_HEIGHT,
		},
		Text_Line{text = "\n", start = 7, length = 1, width = 0, height = MOCK_LINE_HEIGHT},
		Text_Line{text = "\n", start = 8, length = 1, width = 0, height = MOCK_LINE_HEIGHT},
	}
	expect_lines(t, lines[:], expected_lines)
}
