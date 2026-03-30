package text

import "core:mem"
import "core:strings"
import "core:testing"
import "core:unicode"
import "core:unicode/utf8"

import base "../base"

// Range is in bytes
Text_Run :: struct {
	range: base.Range,
}

Paragraph :: struct {
	text_range:     base.Range,
	text_run_range: base.Range,
	glyph_range:    base.Range,
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

Linebreak_Kind :: enum {
	Word,
	Hyphen,
	Grapheme_Cluster,
}

// TODO(Thomas): Should this be a byte range instead, e.g. for Grapheme_Cluster in the future.
Linebreak_Candidate :: struct {
	kind:      Linebreak_Kind,
	glyph_idx: int,
}

Positioned_Row :: struct {
	pos:         base.Vec2,
	size:        base.Vec2,
	glyph_range: base.Range,
}

Text_Layout :: struct {
	size: base.Vec2,
	rows: []Positioned_Row,
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

	if start < byte_pos {
		append(paragraphs, Paragraph{text_range = {start = start, end = len(text)}})
	}
}


// TODO(Thomas): Better name?
style_analysis :: proc(paragraphs: []Paragraph, text_runs: ^[dynamic]Text_Run) {
	// TODO(Thomas): This looks a little dumb right now, but sets us up for being able
	// to deal with multiple Text_Runs in a single paragraph later.
	text_run_start := 0
	text_run_end := 0
	for &paragraph in paragraphs {
		text_run_end += 1
		append(text_runs, Text_Run{range = paragraph.text_range})
		paragraph.text_run_range = base.Range {
			start = text_run_start,
			end   = text_run_end,
		}
		text_run_start = text_run_end
	}
}

// TODO(Thomas): We won't really do anything here to begin with I think.
// We'll try to stub it out though, so the pipeline and data types is right.
bidi_analysis :: proc() {}

// TODO(Thomas): Should aim for having actual correct clusters even for simple v0 version,
// but might prove hard without actual shaping library.
shaping :: proc(
	text: string,
	paragraphs: []Paragraph,
	text_runs: []Text_Run,
	glyphs: ^[dynamic]Glyph,
	measure_codepoint_proc: Measure_Codepoint_Proc,
) {
	// TODO(Thomas): font_id Font_Handle is hardcoded here for now, this should come
	// in with other contextual stuff that we need, probably / maybe stored on the Text_Run?
	FONT_ID :: 0
	glyph_start := 0
	glyph_end := 0
	for &paragraph in paragraphs {
		runs := text_runs[paragraph.text_run_range.start:paragraph.text_run_range.end]
		for run in runs {
			sub := text[run.range.start:run.range.end]
			// TODO(Thomas): BIG HACK - Glyph end idx using byte idx in the sub here is VERY temporary
			// just to make something work for ASCII to have the pipeline up and running.
			// Not sure how we should deal with this, but this is probably where the meat of the shaping is coming in
			for r in sub {
				glyph_end += 1
				// TODO(Thomas): This will have to be cached of course.
				codepoint_metrics := measure_codepoint_proc(r, FONT_ID, nil)
				append(glyphs, Glyph{codepoint = r, metrics = codepoint_metrics})
			}
		}
		paragraph.glyph_range = base.Range {
			start = glyph_start,
			end   = glyph_end,
		}
		glyph_start = glyph_end
	}
}

// TODO(Thomas): Implement other linbreak kinds too.
// TODO(Thomas): Think about whether Glyph is the right level here,
// grapheme clusters are the more correct version. This means that
// could / should happen before shaping, where we produce the Glyphs.
// Using glyph here now just makes it easy to have a pipeline setup
// that can replace the old text setup
find_linebreak_candidates :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: ^[dynamic]Linebreak_Candidate,
) {

	glyph_idx := 0
	for paragraph in paragraphs {
		paragraph_glyphs := glyphs[paragraph.glyph_range.start:paragraph.glyph_range.end]
		for glyph in paragraph_glyphs {
			if unicode.is_white_space(glyph.codepoint) {
				append(
					linebreak_candidates,
					Linebreak_Candidate{kind = .Word, glyph_idx = glyph_idx},
				)
			}
			glyph_idx += 1
		}
	}
}

layout_rows :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: []Linebreak_Candidate,
	rows: ^[dynamic]Positioned_Row,
	max_width: f32,
	line_height: f32,
) {

	EPSILON :: 0.001

	line_height_offset: f32 = 0
	start_idx := 0
	current_idx := 0

	for paragraph in paragraphs {
		row_width: f32 = 0
		paragraph_glyphs := glyphs[paragraph.glyph_range.start:paragraph.glyph_range.end]

		// Algorithm outline:
		// Greedily accumulate glyphs until we overflow the max width or run out of glyphs.
		// If we overflow, we look for the previous line break candidate
		// These are last whitespace before new word e.g. word wrapping, hyphens or grapheme cluster boundaries.

		for glyph in paragraph_glyphs {
			if row_width + glyph.metrics.width > max_width + EPSILON {
				// Find best line break candidate
				best_candidate_glyph_idx := -1
				for candidate in linebreak_candidates {
					// NOTE(Thomas): This works because candidate glyph idx is sorted.
					if candidate.glyph_idx < current_idx {
						best_candidate_glyph_idx = candidate.glyph_idx
					} else {
						break
					}
				}

				// If there are no best candidate glyph idx,
				// then we use the current glyph as the best candidate.
				// TODO(Thomas): I think a better approach here if there are no
				// line break candidates before this, is that we break on the previous
				// glyph idx.
				if best_candidate_glyph_idx == -1 {
					if current_idx > 0 {
						best_candidate_glyph_idx = current_idx - 1
					} else {
						best_candidate_glyph_idx = 0
					}
				}

				// Now we have the line break candidate, so we need to construct the row
				// and append it. There might be several glyphs between the candidate and the
				// current glyph idx, so we need to calculate row width in a different way.
				// We iterate through glyphs from start_idx to inclusive best_candidate_glyph_idx
				// and add up to find the actual row width.
				actual_row_width: f32 = 0
				for i in start_idx ..= best_candidate_glyph_idx {
					actual_row_width += glyphs[i].metrics.width
				}

				// TODO(Thomas): What to do with trailing whitespace here?
				// We have cases where we overflow on whitespace, meaning that width of the
				// row then will be larger than the max size.
				append(
					rows,
					Positioned_Row {
						pos = base.Vec2{0, line_height_offset},
						size = base.Vec2{actual_row_width, line_height},
						// TODO(Thomas): Make sure that best_candidate_glyph_idx + 1 is safe.
						// End glyph range is [start, end), so we need to go one past
						glyph_range = {start = start_idx, end = best_candidate_glyph_idx + 1},
					},
				)

				// Need to add up the row_width for the glyphs that are overflowing onto the next line
				// and set row_width to them.
				new_line_row_width: f32 = 0
				for i in (best_candidate_glyph_idx) ..< current_idx {
					new_line_row_width += glyphs[i].metrics.width
				}

				// TODO(Thomas): Make sure that best_candidate_glyph_idx + 1 is safe.
				// Next line needs to start on the glyph after the best line break candidate
				start_idx = best_candidate_glyph_idx + 1
				row_width = new_line_row_width
				line_height_offset += line_height
			} else {
				row_width += glyph.metrics.width
			}

			current_idx += 1
		}

		append(
			rows,
			Positioned_Row {
				pos = base.Vec2{0, line_height_offset},
				size = base.Vec2{row_width, line_height},
				glyph_range = {start = start_idx, end = current_idx},
			},
		)
		start_idx = current_idx
		line_height_offset += line_height
	}
}

// TODO(Thomas): We need to think about good allocation strategies here,
// can we get away with an arena, e.g. the frame arena?
// Don't return an instance of Text_Layout here? Take in ^Text_Layout instead?
// It holds a slice into the rows, which is allocated by the passed in allocator,
// so that lifetime needs to be made explicit and obvious at least.
layout_text :: proc(
	text: string,
	available_width: f32,
	font_handle: Font_Handle,
	measure_codepoint_proc: Measure_Codepoint_Proc,
	measure_text_proc: Measure_Text_Proc,
	allocator: mem.Allocator,
) -> Text_Layout {

	// TODO(Thomas): This should be cached of course.
	text_metrics := measure_text_proc(text, font_handle, nil)

	// Minimal pipeline for now
	paragraphs := make([dynamic]Paragraph, allocator)
	paragraph_segmentation(text, &paragraphs)

	text_runs := make([dynamic]Text_Run, allocator)
	style_analysis(paragraphs[:], &text_runs)

	glyphs := make([dynamic]Glyph, allocator)

	// TODO(Thomas): Missing passing / retrieving right data types to/from bidi_analysis
	bidi_analysis()

	shaping(text, paragraphs[:], text_runs[:], &glyphs, measure_codepoint_proc)

	// TODO(Thomas): This should probably be done before shaping and on grapheme clusters
	// and not on glyphs
	linebreak_candidates := make([dynamic]Linebreak_Candidate, allocator)
	find_linebreak_candidates(paragraphs[:], glyphs[:], &linebreak_candidates)

	rows := make([dynamic]Positioned_Row, allocator)
	layout_rows(
		paragraphs[:],
		glyphs[:],
		linebreak_candidates[:],
		&rows,
		available_width,
		text_metrics.line_height,
	)

	// TODO(Thomas): This could be done in layout_rows instead so we don't have
	// to iteratte over the rows again here.
	layout_size := base.Vec2{}
	for row in rows {
		layout_size.x = max(layout_size.x, row.size.x)
		layout_size.y += row.size.y
	}
	return Text_Layout{size = layout_size, rows = rows[:]}
}

// ------------ TESTS -------------

MOCK_CHAR_WIDTH :: 10
MOCK_LINE_HEIGHT :: 10
MOCK_FONT_HANDLE :: 0

mock_measure_codepoint_proc :: proc(
	codepoint: rune,
	font_id: Font_Handle,
	user_data: rawptr,
) -> Codepoint_Metrics {
	width: f32 = 0
	left_bearing: f32 = 0
	if codepoint != '\n' {
		width = MOCK_CHAR_WIDTH
		left_bearing = MOCK_CHAR_WIDTH
	}
	return Codepoint_Metrics{width = width, left_bearing = left_bearing}
}

mock_measure_text_proc :: proc(
	text: string,
	font_id: Font_Handle,
	user_data: rawptr,
) -> Text_Metrics {
	width: f32 = f32(strings.rune_count(text) * MOCK_CHAR_WIDTH)
	line_height: f32 = MOCK_LINE_HEIGHT

	return Text_Metrics{width = width, line_height = line_height}
}

expect_positioned_rows :: proc(
	t: ^testing.T,
	positioned_rows: []Positioned_Row,
	expected_positioned_rows: []Positioned_Row,
) {
	testing.expect_value(t, len(positioned_rows), len(expected_positioned_rows))
	for row, idx in positioned_rows {
		testing.expect_value(t, row, expected_positioned_rows[idx])
	}
}

expect_text_layout :: proc(
	t: ^testing.T,
	text_layout: Text_Layout,
	expected_text_layout: Text_Layout,
) {
	testing.expect_value(t, text_layout.size, expected_text_layout.size)
	expect_positioned_rows(t, text_layout.rows, expected_text_layout.rows)
}

@(test)
test_layout_text :: proc(t: ^testing.T) {
	text := "Hello\nWorld"

	expected_text_layout := Text_Layout {
		size = base.Vec2{5 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		rows = {
			Positioned_Row {
				pos = base.Vec2{},
				size = base.Vec2{5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 0, end = 6},
			},
			Positioned_Row {
				pos = base.Vec2{0, MOCK_LINE_HEIGHT},
				size = base.Vec2{5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 6, end = 11},
			},
		},
	}

	text_layout := layout_text(
		text,
		100.0,
		MOCK_FONT_HANDLE,
		mock_measure_codepoint_proc,
		mock_measure_text_proc,
		context.temp_allocator,
	)
	defer free_all(context.temp_allocator)

	expect_text_layout(t, text_layout, expected_text_layout)
}

@(test)
test_layout_text_single_newline_char :: proc(t: ^testing.T) {
	text := "\n"

	expected_text_layout := Text_Layout {
		size = base.Vec2{0, MOCK_LINE_HEIGHT},
		rows = {
			Positioned_Row {
				pos = base.Vec2{},
				size = base.Vec2{0, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 0, end = 1},
			},
		},
	}

	text_layout := layout_text(
		text,
		100.0,
		MOCK_FONT_HANDLE,
		mock_measure_codepoint_proc,
		mock_measure_text_proc,
		context.temp_allocator,
	)
	defer free_all(context.temp_allocator)

	expect_text_layout(t, text_layout, expected_text_layout)
}

@(test)
test_layout_text_exactly_fits :: proc(t: ^testing.T) {
	text := "0123456789"

	expected_text_layout := Text_Layout {
		size = base.Vec2{10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
		rows = {
			Positioned_Row {
				pos = base.Vec2{},
				size = base.Vec2{10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 0, end = 10},
			},
		},
	}

	text_layout := layout_text(
		text,
		100.0,
		MOCK_FONT_HANDLE,
		mock_measure_codepoint_proc,
		mock_measure_text_proc,
		context.temp_allocator,
	)

	defer free_all(context.temp_allocator)

	expect_text_layout(t, text_layout, expected_text_layout)
}

// TODO(Thomas): Think about correctness of this test. We overflow max size with 10
// here because we're breaking on the whitespace between words, which is the only
// linebreak candidate here, and the whitespace is included.
//@(test)
//test_layout_break_on_whitespace_between_words :: proc(t: ^testing.T) {
//	text := "strawberry accomplish"
//
//	expected_text_layout := Text_Layout {
//		size = base.Vec2{10 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
//		rows = {
//			Positioned_Row {
//				pos = base.Vec2{},
//				size = base.Vec2{10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
//				glyph_range = base.Range{start = 0, end = 10},
//			},
//			Positioned_Row {
//				pos = base.Vec2{0, MOCK_LINE_HEIGHT},
//				size = base.Vec2{10 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
//				glyph_range = base.Range{start = 10, end = 21},
//			},
//		},
//	}
//
//	text_layout := layout_text(
//		text,
//		100.0,
//		MOCK_FONT_HANDLE,
//		mock_measure_codepoint_proc,
//		mock_measure_text_proc,
//		context.temp_allocator,
//	)
//
//	defer free_all(context.temp_allocator)
//
//	expect_text_layout(t, text_layout, expected_text_layout)
//}

@(test)
test_layout_break :: proc(t: ^testing.T) {
	text := "one two three"

	expected_text_layout := Text_Layout {
		size = base.Vec2{8 * MOCK_CHAR_WIDTH, 2 * MOCK_LINE_HEIGHT},
		rows = {
			Positioned_Row {
				pos = base.Vec2{},
				size = base.Vec2{8 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 0, end = 8},
			},
			Positioned_Row {
				pos = base.Vec2{0, MOCK_LINE_HEIGHT},
				size = base.Vec2{5 * MOCK_CHAR_WIDTH, MOCK_LINE_HEIGHT},
				glyph_range = base.Range{start = 8, end = 13},
			},
		},
	}

	text_layout := layout_text(
		text,
		100.0,
		MOCK_FONT_HANDLE,
		mock_measure_codepoint_proc,
		mock_measure_text_proc,
		context.temp_allocator,
	)

	defer free_all(context.temp_allocator)

	expect_text_layout(t, text_layout, expected_text_layout)
}
