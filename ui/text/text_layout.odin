package text

import "core:strings"
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

Text_Unit_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Unit_Range :: struct {
	start: int,
	end:   int,
}

Text_Unit :: struct {
	kind:  Text_Unit_Kind,
	range: Text_Unit_Range,
}

tokenize_text :: proc(text: string, text_units: ^[dynamic]Text_Unit) {
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
					text_units,
					Text_Unit{kind = .Newline, range = {start = start_pos, end = rune_pos}},
				)

			} else {
				// TODO(Thomas): What to do with multiple whitespace in a row?
				// Accumulate them into a single Text_Unit?
				// What about tabs? Make them into spaces probably?
				// TODO(Thomas): Or go the easy route that will produce more Text_Unit
				// instances, but will make the tokenization simpler.
			}

		} else {
			// This is part of a word, keep eating runes until we reach newline or whitespace

		}
	}


}
