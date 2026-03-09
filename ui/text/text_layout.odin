package text

import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

// Text Layout algorithm
// The layout algorithms will be split into several phases.
// Step 1: Tokenize text
// Convert the input string into a sequence of tokens:
// * Word
// * Whitespace (space, tab etc)
// * Newline
//
// This is similar to how the old version did it.
// Step 2: Shaping
// for each token:
//  * if newline, no glyphs
//  * otherwise map codepoints to glyphs
//  * measure advances
//  * build a Glyph_Run
//
// No advanced shaping required at first, Harbuzz possible later.
// Step 3: Layout lines
// We'll go for a greedy approach for laying out lines.
// Look at existing implementation, can probably be imrpoved.
//
// Step 4: Compute line metrics
// TODO
//
// Step 5: Position glyphs
// TODO

// BiDi related
Direction :: enum {
	Left_To_Right,
	Right_To_Left,
}

Text_Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

// TODO(Thomas): Bytes or runes????
Text_Token_Range :: struct {
	start: int,
	end:   int,
}

Text_Token :: struct {
	kind:  Text_Token_Kind,
	range: Text_Token_Range,
}


tokenize_text :: proc(text: string, font_id: u16, text_tokens: ^[dynamic]Text_Token) {
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

// ------------ TESTS -------------

expect_tokens :: proc(t: ^testing.T, tokens: []Text_Token, expected_tokens: []Text_Token) {
	testing.expect_value(t, len(tokens), len(expected_tokens))
	for token, idx in tokens {
		testing.expect_value(t, token, expected_tokens[idx])
	}
}

@(test)
test_tokenize_text :: proc(t: ^testing.T) {
	text := "Hello\n"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, 0, &tokens)
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
	tokenize_text(text, 0, &tokens)
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
	tokenize_text(text, 0, &tokens)
	expected_tokens := []Text_Token{Text_Token{kind = .Word, range = {start = 0, end = 1}}}
	expect_tokens(t, tokens[:], expected_tokens)
}

@(test)
test_tokenize_with_whitespace :: proc(t: ^testing.T) {
	text := "Hello World"

	tokens := make([dynamic]Text_Token, context.temp_allocator)
	defer free_all(context.temp_allocator)
	tokenize_text(text, 0, &tokens)
	expected_tokens := []Text_Token {
		Text_Token{kind = .Word, range = {start = 0, end = 5}},
		Text_Token{kind = .Whitespace, range = {start = 5, end = 6}},
		Text_Token{kind = .Word, range = {start = 6, end = 11}},
	}
	expect_tokens(t, tokens[:], expected_tokens)
}
