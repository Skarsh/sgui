package text

import "core:testing"
import "core:unicode/utf8"

import base "../base"

Byte_Idx :: int

Text_Range :: struct {
	start: Byte_Idx,
	end:   Byte_Idx,
}

Text_Run :: struct {
	range: Text_Range,
}

Paragraph :: struct {
	range: Text_Range,
}

Text_Style :: struct {
	font_id:   Font_Handle,
	font_size: f32,
	color:     base.Color,
}

// TODO(Thomas): Is Style_Span or Style_Run a better name?
Style_Range :: struct {
	style: Text_Style,
	range: Text_Range,
}

// TODO(Thomas): codepoint isn't really a rune, this should probably be something else.
// Not sure what yet though.
Glyph :: struct {
	codepoint: rune,
	advance:   f32,
}

Positioned_Glyph :: struct {
	pos:   base.Vec2,
	glyph: Glyph,
}

Glyph_Idx :: int

Line :: struct {
	start: Glyph_Idx,
	end:   Glyph_Idx,
}

paragraph_segmentation :: proc(text: string, paragraphs: ^[dynamic]Paragraph) {
	if len(text) == 0 {
		return
	}

	byte_pos := 0
	start := 0
	for byte_pos < len(text) {
		r, width := utf8.decode_rune_in_string(text[byte_pos:])
		assert(width > 0)

		byte_pos += width

		if r == '\n' {
			append(paragraphs, Paragraph{range = {start = start, end = byte_pos}})
			start = byte_pos
		}
	}

	append(paragraphs, Paragraph{range = {start = start, end = len(text)}})
}


// TODO(Thomas): Better name?
style_analysis :: proc() {}

// TODO(Thomas): We won't really do anything here to begin with I think.
// We'll stub this one out so we
bidi_analysis :: proc() {}

shaping :: proc(text: string, run: Text_Run) -> []Glyph {
	// TODO(Thomas): Doing a very simple version here now
	// Thinking about just calling a simple measure_width procedure or
	// something for the text that the Text_Run represents, just something
	// that is good enough for making simple glyphs for ASCII text.
	// Should aim for having actual correct clusters though, but might prove
	// hard without actual shaping library.
	return nil
}

layout_lines :: proc(glyphs: []Glyph, max_width: f32) -> []Line {
	return nil
}

layout_text :: proc(text: string, available_width: f32) -> []Positioned_Glyph {

	// Minimal pipeline for now

	shaping("", Text_Run{})

	glyphs: [10]Glyph = {}
	_ = layout_lines(glyphs[:], 0)

	// TODO(Thomas: Step for producing Positioned_Glyphs from lines is missing

	return nil
}

// ------------ TESTS -------------

expect_paragraphs :: proc(
	t: ^testing.T,
	paragraphs: []Paragraph,
	expected_paragraphs: []Paragraph,
) {
	testing.expect_value(t, len(paragraphs), len(expected_paragraphs))
	for paragraph, idx in paragraphs {
		testing.expect_value(t, paragraph, expected_paragraphs[idx])
	}
}

@(test)
test_paragraph_segmentation :: proc(t: ^testing.T) {
	text := "Hello\nWorld"

	paragraphs := make([dynamic]Paragraph, context.temp_allocator)
	defer free_all(context.temp_allocator)

	paragraph_segmentation(text, &paragraphs)
	expected_paragraphs := []Paragraph {
		Paragraph{Text_Range{start = 0, end = 6}},
		Paragraph{Text_Range{start = 6, end = 11}},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs)
}


@(test)
test_paragraph_segmentation_empty_paragraph_between :: proc(t: ^testing.T) {
	text := "Hello\n\nWorld"
	paragraphs := make([dynamic]Paragraph, context.temp_allocator)
	defer free_all(context.temp_allocator)

	paragraph_segmentation(text, &paragraphs)
	expected_paragraphs := []Paragraph {
		Paragraph{Text_Range{start = 0, end = 6}},
		Paragraph{Text_Range{start = 6, end = 7}},
		Paragraph{Text_Range{start = 7, end = 12}},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs[:])
}
