package ui

import "core:log"
import "core:mem"
import "core:strings"
import "core:testing"
import "core:unicode/utf8"

Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Token :: struct {
	start: int, // Byte start in original string
	end:   int, // Byte end in original string
	width: f32, // Measured width
	kind:  Token_Kind,
}

Text_Line_2 :: struct {
	start:  int, // Byte start in original string
	end:    int, // Byte end in original string (before trimming)
	width:  f32, // Vistual width
	height: f32, // Line height
}

tokenize_text :: proc(ctx: ^Context, text: string, font_id: u16, tokens: ^[dynamic]Text_Token) {
	if len(text) == 0 {
		return
	}

	clear_dynamic_array(tokens)

	byte_pos := 0
	for byte_pos < len(text) {
		start_pos := byte_pos
		c := text[byte_pos]
		switch c {
		case ' ', '\t':
			// Collect whitespace
			for byte_pos < len(text) && (text[byte_pos] == ' ' || text[byte_pos] == '\t') {
				byte_pos += 1
			}
			// TODO(Thomas): What to do with '\t' when it comes to measuring string width here?
			width := measure_string_width(ctx, text[start_pos:byte_pos], font_id)
			append(
				tokens,
				Text_Token{start = start_pos, end = byte_pos, width = width, kind = .Whitespace},
			)

		case '\n':
			// Single newline
			byte_pos += 1
			append(
				tokens,
				Text_Token{start = start_pos, end = byte_pos, width = 0, kind = .Newline},
			)
		case:
			// Collect words (everything that's not space, tab or newline)
			for byte_pos < len(text) {
				b := text[byte_pos]
				if b == ' ' || b == '\t' || b == '\n' {
					// We've found a word boundary, so we break
					break
				}

				// Handle UTF-8: if high bit set, skip continuation bytes
				// 0x80 (0b10000000) is the high bit in UTF8, if this is set this means
				// that we're dealing with a multi-byte non-ascii character.
				if b >= 0x80 {
					byte_pos += 1
					// 0xC0 = 11000000 so we get the top two bits, then we check if
					// it's equal to == 0x80, if that is true, the top two bits must be 10
					// which in UTF-8 means that this is a continuation byte
					for byte_pos < len(text) && (text[byte_pos] & 0xC0) == 0x80 {
						byte_pos += 1
					}
				} else {
					byte_pos += 1
				}
			}
			width := measure_string_width(ctx, text[start_pos:byte_pos], font_id)
			append(
				tokens,
				Text_Token{start = start_pos, end = byte_pos, width = width, kind = .Word},
			)
		}
	}
}

layout_lines :: proc(
	ctx: ^Context,
	text: string,
	tokens: []Text_Token,
	max_width: f32,
	line_height: f32,
	lines: ^[dynamic]Text_Line_2,
) {
	// Iterate over each token
	// check which type the token is
	// Start with new line, because we need to handle that first.
	// Newline kind automatic triggers the creation of a new Text_Line
	// For the Word kind we need to check if it fits the current line
	// if it does, we just increment "cursor" and keep going, if it
	// doesn't we have to make a new Text_Line
	// For the Whitespace kind we keep whichever is inserted manually after a newline
	// and those that are inbetween words. Trailing whitespace we don't care about.

	line_start_token := 0
	line_end_token := 0
	line_width: f32 = 0
	line_word_idx := 0

	for token, i in tokens {
		switch token.kind {
		case .Newline:
			line := Text_Line_2 {
				start  = tokens[line_start_token].start,
				end    = tokens[line_end_token].end,
				width  = line_width,
				height = line_height,
			}
			append(lines, line)
			line_width = 0
			line_word_idx = 0
		case .Word:
			// Here we need to check if the word fits on the current line, if not we have to make a new line
			// and put the word there
			if line_width >= max_width && i > line_word_idx {
				line := Text_Line_2 {
					start  = tokens[line_start_token].start,
					end    = tokens[line_end_token].end,
					width  = line_width,
					height = line_height,
				}
				append(lines, line)
				line_width = 0
				line_word_idx = 0
			} else {
				line_width += token.width
				line_word_idx += 1
			}
		case .Whitespace:
		}
	}
}

Word :: struct {
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


word_to_string :: proc(text: string, word: Word) -> (string, bool) {
	return strings.substring(text, word.start_offset, word.start_offset + word.length)
}

measure_text_words :: proc(
	ctx: ^Context,
	text: string,
	font_id: u16,
	allocator: mem.Allocator,
) -> []Word {
	words, alloc_err := make([dynamic]Word, allocator)
	assert(alloc_err == .None)

	if len(text) == 0 {
		return words[:]
	}

	start := 0
	i := 0
	for r in text {
		rune_size := utf8.rune_size(r)
		if r == ' ' {
			if i > start {
				// Measure the word
				word_text := text[start:i]
				word_width := measure_string_width(ctx, word_text, font_id)
				append(&words, Word{start_offset = start, length = i - start, width = word_width})
			}
			start = i + rune_size
		} else if r == '\n' {
			if i > start {
				// Measure the word
				word_text := text[start:i]
				word_width := measure_string_width(ctx, word_text, font_id)
				append(&words, Word{start_offset = start, length = i - start, width = word_width})
			}
			start = i + rune_size

			// Append word with 0 width to signal that it's a newline
			append(&words, Word{start_offset = start, length = 0, width = 0})
		}


		i += rune_size
	}

	if i > start {
		word_width := measure_string_width(ctx, text[start:i], font_id)
		append(&words, Word{start_offset = start, length = i - start, width = word_width})
	}

	return words[:]
}

// TODO(Thomas): Handle newlines
calculate_text_lines :: proc(
	ctx: ^Context,
	text: string,
	words: []Word,
	config: Text_Element_Config,
	element_width: f32,
	font_id: u16,
	font_size: f32,
	allocator: mem.Allocator,
) -> []Text_Line {
	lines, alloc_err := make([dynamic]Text_Line, allocator)
	assert(alloc_err == .None)

	first_word_on_line_idx := 0
	current_line_width: f32 = 0
	space_width := measure_glyph_width(ctx, ' ', font_id)

	for word, idx in words {
		word_width := word.width
		just_processed_newline := false
		if word_width == 0 && word.length == 0 {
			make_and_push_line(
				&lines,
				text,
				words[first_word_on_line_idx],
				words[idx - 1],
				current_line_width,
				measure_string_line_height(ctx, text, font_id),
			)
			// Start new line with current word
			first_word_on_line_idx = idx
			current_line_width = word.width
			just_processed_newline = true
		} else {
			// Check if we need whitespace before this word (not for first word on line)
			needs_whitespace := idx > first_word_on_line_idx
			width_with_word :=
				current_line_width + (needs_whitespace ? space_width : 0) + word_width

			// We need to wrap onto a new line
			if width_with_word >= element_width && idx > first_word_on_line_idx {
				// Push the current line (from first_word_on_line_idx to current word exclusive)
				make_and_push_line(
					&lines,
					text,
					words[first_word_on_line_idx],
					words[idx - 1],
					current_line_width,
					measure_string_line_height(ctx, text, font_id),
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

		}

		// Handle last word
		if idx == len(words) - 1 && just_processed_newline == false {
			make_and_push_line(
				&lines,
				text,
				words[first_word_on_line_idx],
				words[idx],
				current_line_width,
				measure_string_line_height(ctx, text, font_id),
			)
		}
	}

	return lines[:]
}

Text_Line :: struct {
	text:   string,
	width:  f32,
	height: f32,
}

make_and_push_line :: proc(
	lines: ^[dynamic]Text_Line,
	s: string,
	first_word: Word,
	last_word: Word,
	width: f32,
	line_height: f32,
) {

	line_start := first_word.start_offset
	line_end := last_word.start_offset + last_word.length
	line, ok := strings.substring(s, line_start, line_end)
	assert(ok)
	trimmed_line := strings.trim_left_space(line)
	append(lines, Text_Line{text = trimmed_line, width = width, height = line_height})
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
