package text

import "core:log"
import "core:testing"
import "core:unicode/utf8"

import base "../base"

// Range is in bytes
Text_Run :: struct {
	range: base.Range,
}

Paragraph :: struct {
	text_range:  base.Range,
	glyph_range: base.Range,
}

Text_Style :: struct {
	font_id:   Font_Handle,
	font_size: f32,
	color:     base.Color,
}

// TODO(Thomas): Is Style_Span or Style_Run a better name?
Style_Range :: struct {
	style:      Text_Style,
	text_range: base.Range,
}

// TODO(Thomas): codepoint isn't really a rune, this should probably be something else.
// Not sure what yet though.
Glyph :: struct {
	codepoint: rune,
	metrics:   Codepoint_Metrics,
}

Positioned_Glyph :: struct {
	pos:   base.Vec2,
	glyph: Glyph,
}

Line :: struct {
	glyph_range: base.Range,
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
			append(paragraphs, Paragraph{text_range = {start = start, end = byte_pos}})
			start = byte_pos
		}
	}

	append(paragraphs, Paragraph{text_range = {start = start, end = len(text)}})
}


// TODO(Thomas): Better name?
style_analysis :: proc(paragraphs: []Paragraph, text_runs: ^[dynamic]Text_Run) {
	for paragraph in paragraphs {
		append(text_runs, Text_Run{range = paragraph.text_range})
	}
}

// TODO(Thomas): We won't really do anything here to begin with I think.
// We'll stub this one out so we
bidi_analysis :: proc() {}

shaping :: proc(
	text: string,
	run: Text_Run,
	glyphs: ^[dynamic]Glyph,
	measure_codepoint_proc: Measure_Codepoint_Proc,
) {
	// TODO(Thomas): Doing a very simple version here now
	// Thinking about just calling a simple measure_width procedure or
	// something for the text that the Text_Run represents, just something
	// that is good enough for making simple glyphs for ASCII text.
	// Should aim for having actual correct clusters though, but might prove
	// hard without actual shaping library.

	// iterate over each
	sub := text[run.range.start:run.range.end]
	// TODO(Thomas): font_id Font_Handle is hardcoded here for now, this should come
	// in with other contextual stuff that we need, probably / maybe stored on the Text_Run?
	font_id :: 0
	for r in sub {
		codepoint_metrics := measure_codepoint_proc(r, font_id, nil)
		append(glyphs, Glyph{codepoint = r, metrics = codepoint_metrics})
	}
}

layout_lines :: proc(glyphs: []Glyph, lines: ^[dynamic]Line, max_width: f32) {
	// TODO(Thomas): Need to break on good line break opporunity here, e.g.
	// the last whitespace before overflowing.
	// Greedy approach, keep accumulating glyphs into the line until it can't fit anymore.
	line_width: f32 = 0
	start_idx := 0
	for glyph, idx in glyphs {
		if line_width + glyph.metrics.width >= max_width {
			append(lines, Line{glyph_range = {start = start_idx, end = idx}})
			start_idx = idx
			line_width = 0
		}

		line_width += glyph.metrics.width
	}

	if line_width > 0 {
		append(lines, Line{glyph_range = {start = start_idx, end = len(glyphs)}})
	}
}

// TODO(Thomas): Hardcoded use of context.allocator here. We need to think about
// good allocation strategies here, can we get away with an arena, e.g. the frame arena?
// TODO(Thomas): Maybe the output type here should be some Row or Line type instead,
// containing Positioned_Glyphs, so that their position is relative to the line baseline.
// Alternatively, if this knows the line height, all the positional information can be stored
// in the Positioned_Glyph instead, but that's a future imrpovement I think.
layout_text :: proc(
	text: string,
	available_width: f32,
	measure_codepoint_proc: Measure_Codepoint_Proc,
) -> []Positioned_Glyph {

	// Minimal pipeline for now
	paragraphs := make([dynamic]Paragraph, context.allocator)
	paragraph_segmentation(text, &paragraphs)

	text_runs := make([dynamic]Text_Run, context.allocator)
	style_analysis(paragraphs[:], &text_runs)

	// TODO(Thomas): We're losing the paragraph segmentation newline break here.
	// What about [dynamic][]Glyph?
	glyphs := make([dynamic]Glyph, context.allocator)
	for text_run in text_runs {
		shaping("", text_run, &glyphs, measure_codepoint_proc)
	}


	lines := make([dynamic]Line, context.allocator)
	layout_lines(glyphs[:], &lines, 0)

	// TODO(Thomas: Step for producing Positioned_Glyphs from lines is missing
	return nil
}

// ------------ TESTS -------------


// TODO(Thomas): Mock procedures and constants here are duplicates from ui/test_harness.odin.
// Should we provide this from this package?? Or is it actually reasonable that usage code that needs to
// mock it does that by themselves?
MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10

mock_measure_codepoint_proc :: proc(
	codepoint: rune,
	font_id: Font_Handle,
	user_data: rawptr,
) -> Codepoint_Metrics {
	width: f32 = MOCK_CHAR_WIDTH
	left_bearing: f32 = MOCK_CHAR_WIDTH
	return Codepoint_Metrics{width = width, left_bearing = left_bearing}
}

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
		Paragraph{text_range = base.Range{start = 0, end = 6}},
		Paragraph{text_range = base.Range{start = 6, end = 11}},
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
		Paragraph{text_range = base.Range{start = 0, end = 6}},
		Paragraph{text_range = base.Range{start = 6, end = 7}},
		Paragraph{text_range = base.Range{start = 7, end = 12}},
	}
	expect_paragraphs(t, paragraphs[:], expected_paragraphs[:])
}

// TODO(Thomas): This isn't testing anything, it's only to have a simple way to
// see output from the different stages easily.
@(test)
test_shaping :: proc(t: ^testing.T) {
	text := "Hello\nWorld"
	paragraphs := make([dynamic]Paragraph, context.temp_allocator)
	defer free_all(context.temp_allocator)

	paragraph_segmentation(text, &paragraphs)

	text_runs := make([dynamic]Text_Run, context.temp_allocator)
	style_analysis(paragraphs[:], &text_runs)

	glyphs := make([dynamic]Glyph, context.temp_allocator)
	for text_run in text_runs {
		shaping(text, text_run, &glyphs, mock_measure_codepoint_proc)
	}

	for glyph in glyphs {
		log.info("glyph: ", glyph)
	}
}
