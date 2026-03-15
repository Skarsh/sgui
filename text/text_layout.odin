package text

import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

import base "../base"

Text_Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Byte_Idx :: int

Text_Range :: struct {
	start: Byte_Idx,
	end:   Byte_Idx,
}

Text_Token :: struct {
	kind:  Text_Token_Kind,
	range: Text_Range,
}

Text_Style :: struct {
	font_id:   base.Font_Handle,
	font_size: f32,
	color:     base.Color,
}

// TODO(Thomas): Is Style_Span or Style_Run a better name?
Style_Range :: struct {
	style: Text_Style,
	range: Text_Range,
}

tokenize_text :: proc(text: string, text_tokens: ^[dynamic]Text_Token) {
	if len(text) == 0 {
		return
	}

	byte_pos := 0
	for byte_pos < len(text) {
		start := byte_pos

		r, width := utf8.decode_rune_in_string(text[byte_pos:])
		assert(width > 0)

		if unicode.is_space(r) {
			byte_pos += width

			kind: Text_Token_Kind = .Whitespace
			if r == '\n' {
				kind = .Newline
			}

			append(
				text_tokens,
				Text_Token{kind = kind, range = Text_Range{start = start, end = byte_pos}},
			)
		} else {
			// Eat whole word
			for byte_pos < len(text) {
				peek_r, peek_width := utf8.decode_rune_in_string(text[byte_pos:])
				assert(peek_width > 0)

				// Found end of word due to whitespace, break the eat loop
				if unicode.is_space(peek_r) {
					break
				}

				byte_pos += peek_width
			}
			append(
				text_tokens,
				Text_Token{kind = .Word, range = Text_Range{start = start, end = byte_pos}},
			)
		}
	}
}

paragraph_segmentation :: proc(
	text: string,
	tokens: []Text_Token,
	paragraphs: ^[dynamic]Text_Range,
) {
	paragraph_start := 0

	for token in tokens {
		if token.kind == .Newline {
			append(paragraphs, Text_Range{start = paragraph_start, end = token.range.end})
			paragraph_start = token.range.end
		}
	}

	// TODO(Thomas): Is this correct??
	// Always append trailing paragraph, even if empty
	append(paragraphs, Text_Range{start = paragraph_start, end = len(text)})
}

// TODO(Thomas): Better name?
style_analysis :: proc() {}

// TODO(Thomas): We won't really do anything here to begin with I think.
// We'll stub this one out so we
bidi_analysis :: proc() {}

// TODO(Thomas): What do we actually do here?
shaping :: proc() {}

layout_text :: proc(text: string, style_ranges: []Style_Range, available_width: f32) {

}

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
	expected_tokens := []Text_Token{Text_Token{kind = .Word, range = {start = 0, end = 2}}}
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

	tokenize_text(text, &tokens)
	paragraph_segmentation(text, tokens[:], &paragraphs)
	expected_paragraphs := []Text_Range {
		Text_Range{start = 0, end = 6},
		Text_Range{start = 6, end = 11},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs[:])
}

@(test)
test_paragraph_segmentation_empty_paragraph_between :: proc(t: ^testing.T) {
	text := "Hello\n\nWorld"
	tokens := make([dynamic]Text_Token, context.temp_allocator)
	paragraphs := make([dynamic]Text_Range, context.temp_allocator)
	defer free_all(context.temp_allocator)

	tokenize_text(text, &tokens)
	paragraph_segmentation(text, tokens[:], &paragraphs)
	expected_paragraphs := []Text_Range {
		Text_Range{start = 0, end = 6},
		Text_Range{start = 6, end = 7},
		Text_Range{start = 7, end = 12},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs[:])
}
