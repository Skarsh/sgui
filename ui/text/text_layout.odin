package text

import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

import base "../../base"

Text_Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Range :: struct {
	start: int,
	end:   int,
}

Text_Token :: struct {
	kind:  Text_Token_Kind,
	range: Text_Range,
}

Style_Run :: struct {
	font_id:    u16,
	font_size:  f32,
	color:      base.Color,
	bidi_level: u8,
	runes:      []rune,
}

tokenize_text :: proc(text: string, text_tokens: ^[dynamic]Text_Token) {
	if len(text) == 0 {
		return
	}

	rune_pos := 0
	start_pos := 0
	rune_count := strings.rune_count(text)

	for rune_pos < rune_count {
		start_pos = rune_pos
		r := utf8.rune_at_pos(text, rune_pos)

		if unicode.is_space(r) {
			if r == '\n' {
				rune_pos += 1
				append(
					text_tokens,
					Text_Token{kind = .Newline, range = {start = start_pos, end = rune_pos}},
				)

			} else {
				rune_pos += 1
				append(
					text_tokens,
					Text_Token{kind = .Whitespace, range = {start = start_pos, end = rune_pos}},
				)
			}

		} else {
			// This is part of a word, keep eating runes until we reach newline or whitespace
			for rune_pos < rune_count {
				peek_r := utf8.rune_at_pos(text, rune_pos)
				if !unicode.is_space(peek_r) {
					rune_pos += 1
				} else {
					// We've reached whitespace, the word is over.
					break
				}
			}

			// This ensures that append even when the word is going to the end of the rune count.
			append(
				text_tokens,
				Text_Token{kind = .Word, range = {start = start_pos, end = rune_pos}},
			)
		}
	}
}

// TODO(Thomas): Not sure if I like having to pass in pointer for both
// these two dynamic arrays, might be better to pass in allocator
paragraph_segmentation :: proc(
	text: string,
	tokens: ^[dynamic]Text_Token,
	paragraphs: ^[dynamic]Text_Range,
) {
	// split into tokens
	// break into lines based on newlines
	// output something like []Text_Range,
	// or maybe Text_Span which holds []runes.
	// Text_Span needs another processing step though

	tokenize_text(text, tokens)

	paragraph_start := 0
	paragraph_end := 0

	for token in tokens {
		if token.kind == .Newline {
			append(paragraphs, Text_Range{start = paragraph_start, end = paragraph_end})
			paragraph_start = paragraph_end
		} else {
			paragraph_end = token.range.end
		}
	}

	// Append the remaining paragraph, this happens when the text ends on
	// a word or whitespace
	if paragraph_end != paragraph_start {
		append(paragraphs, Text_Range{start = paragraph_start, end = paragraph_end})
	}
}

// TODO(Thomas): Better name?
style_analysis :: proc() {}

bidi_analysis :: proc() {}

shaping :: proc() {}

// ------------ TESTS -------------

expect_tokens :: proc(t: ^testing.T, tokens: []Text_Token, expected_tokens: []Text_Token) {
	testing.expect_value(t, len(tokens), len(expected_tokens))
	for token, idx in tokens {
		testing.expect_value(t, token, expected_tokens[idx])
	}
}

expect_paragraphs :: proc(
	t: ^testing.T,
	paragraphs: []Text_Range,
	expected_paragraphs: []Text_Range,
) {
	testing.expect_value(t, len(paragraphs), len(expected_paragraphs))
	for paragraph, idx in paragraphs {
		testing.expect_value(t, paragraph, expected_paragraphs[idx])
	}
}

@(test)
test_tokenize_text :: proc(t: ^testing.T) {
	text := "Hello\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Newline, range = {start = 5, end = 6}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_text_word_after_newline :: proc(t: ^testing.T) {
	text := "Hello\nWorld"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Newline, range = {start = 5, end = 6}},
		Text_Token{kind = .Word, range = {start = 6, end = 11}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_unicode_glyph :: proc(t: ^testing.T) {
	text := "©"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token{Text_Token{kind = .Word, range = {start = 0, end = 1}}}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_with_whitespace :: proc(t: ^testing.T) {
	text := "Hello World"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Whitespace, range = {start = 5, end = 6}},
		Text_Token{kind = .Word, range = {start = 6, end = 11}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_with_multiple_single_sequential_whitespace :: proc(t: ^testing.T) {
	text := "Hello  World"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Whitespace, range = {start = 5, end = 6}},
		Text_Token{kind = .Whitespace, range = {start = 6, end = 7}},
		Text_Token{kind = .Word, range = {start = 7, end = 12}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_with_tab_whitespace :: proc(t: ^testing.T) {
	text := "Hello\tWorld"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Whitespace, range = {start = 5, end = 6}},
		Text_Token{kind = .Word, range = {start = 6, end = 11}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_paragraph_segmentation :: proc(t: ^testing.T) {
	text := "Hello\nWorld"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	paragraphs := make([dynamic]Text_Range, context.temp_allocator)
	defer free_all(context.temp_allocator)

	paragraph_segmentation(text, &tokens, &paragraphs)
	expected_paragraphs := []Text_Range {
		Text_Range{start = 0, end = 5},
		Text_Range{start = 5, end = 11},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs[:])
}
