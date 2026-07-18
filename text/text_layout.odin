package text

import "core:mem"
import "core:unicode"
import "core:unicode/utf8"

import base "../base"

Text_Wrap_Mode :: enum {
	None,
	Truncate,
	Wrap,
}

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

// TODO(Thomas): Add field to track size that's without trailing whitespace
Positioned_Row :: struct {
	pos:         base.Vec2,
	size:        base.Vec2,
	glyph_range: base.Range,
}

Text_Layout :: struct {
	size:   base.Vec2,
	rows:   []Positioned_Row,
	glyphs: []Glyph,
}

paragraph_segmentation :: proc(
	text: string,
	paragraphs: ^[dynamic]Paragraph,
) -> mem.Allocator_Error {
	if len(text) == 0 {
		return nil
	}

	byte_pos := 0
	start := 0
	for byte_pos < len(text) {
		r, width := utf8.decode_rune_in_string(text[byte_pos:])
		assert(width > 0)

		byte_pos += width

		if r == '\n' {
			append(paragraphs, Paragraph{text_range = {start = start, end = byte_pos}}) or_return
			start = byte_pos
		}
	}

	if start < byte_pos {
		append(paragraphs, Paragraph{text_range = {start = start, end = len(text)}}) or_return
	}
	return nil
}


// TODO(Thomas): Better name?
style_analysis :: proc(
	paragraphs: []Paragraph,
	text_runs: ^[dynamic]Text_Run,
) -> mem.Allocator_Error {
	// TODO(Thomas): This looks a little dumb right now, but sets us up for being able
	// to deal with multiple Text_Runs in a single paragraph later.
	text_run_start := 0
	text_run_end := 0
	for &paragraph in paragraphs {
		text_run_end += 1
		append(text_runs, Text_Run{range = paragraph.text_range}) or_return
		paragraph.text_run_range = base.Range {
			start = text_run_start,
			end   = text_run_end,
		}
		text_run_start = text_run_end
	}
	return nil
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
	font_user_data: rawptr,
) -> mem.Allocator_Error {
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
				codepoint_metrics := measure_codepoint_proc(r, FONT_ID, font_user_data)
				append(glyphs, Glyph{codepoint = r, metrics = codepoint_metrics}) or_return
			}
		}
		paragraph.glyph_range = base.Range {
			start = glyph_start,
			end   = glyph_end,
		}
		glyph_start = glyph_end
	}
	return nil
}

// TODO(Thomas): Implement other linebreak kinds too.
// TODO(Thomas): Think about whether Glyph is the right level here,
// grapheme clusters are the more correct version. This means that
// could / should happen before shaping, where we produce the Glyphs.
// Using glyph here now just makes it easy to have a pipeline setup
// that can replace the old text setup
find_linebreak_candidates :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: ^[dynamic]Linebreak_Candidate,
) -> mem.Allocator_Error {
	glyph_idx := 0
	for paragraph in paragraphs {
		paragraph_glyphs := glyphs[paragraph.glyph_range.start:paragraph.glyph_range.end]
		for glyph in paragraph_glyphs {
			if unicode.is_white_space(glyph.codepoint) {
				append(
					linebreak_candidates,
					Linebreak_Candidate{kind = .Word, glyph_idx = glyph_idx},
				) or_return
			}
			glyph_idx += 1
		}
	}
	return nil
}

layout_rows :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: []Linebreak_Candidate,
	rows: ^[dynamic]Positioned_Row,
	max_width: f32,
	line_height: f32,
	text_wrap_mode: Text_Wrap_Mode,
) -> mem.Allocator_Error {

	EPSILON :: 0.001
	candidate_cursor := 0
	line_height_offset: f32 = 0

	for paragraph in paragraphs {
		row_start := paragraph.glyph_range.start
		row_width: f32 = 0
		break_candidate_idx := -1

		// Algorithm outline:
		// Greedily accumulate glyphs until we overflow the max width or run out of glyphs.
		// If we overflow, we look for the previous line break candidate
		// These are last whitespace before new word e.g. word wrapping, hyphens or grapheme cluster boundaries.

		for i in paragraph.glyph_range.start ..< paragraph.glyph_range.end {
			glyph := glyphs[i]

			// Keep track of the latest line break candidate
			for candidate_cursor < len(linebreak_candidates) &&
			    linebreak_candidates[candidate_cursor].glyph_idx <= i {
				candidate := linebreak_candidates[candidate_cursor]
				if candidate.glyph_idx == i {
					break_candidate_idx = i
				}
				candidate_cursor += 1
			}

			if row_width + glyph.metrics.width > max_width + EPSILON {
				switch text_wrap_mode {
				case .None:
					row_width += glyph.metrics.width
				case .Truncate:
					if row_width + glyph.metrics.width < max_width {
						row_width += glyph.metrics.width
					}
				case .Wrap:
					break_at_idx: int
					if break_candidate_idx >= row_start {
						break_at_idx = break_candidate_idx
					} else {
						break_at_idx = max(i - 1, row_start)
					}

					// Find the row width
					actual_row_width: f32 = 0
					for j in row_start ..= break_at_idx {
						actual_row_width += glyphs[j].metrics.width
					}

					// TODO(Thomas): What to do with trailing whitespace here?
					// We have cases where we overflow on whitespace, meaning that width of the
					// row then will be larger than the max size.
					// We should probably have two different sizes here, one that is the size including the
					// trailing whitespace for calculating hit tests etc, and one for the content width which
					// would be used in cases where you don't want to show trailling whitespace.
					append(
						rows,
						Positioned_Row {
							pos = {0, line_height_offset},
							size = {actual_row_width, line_height},
							glyph_range = {start = row_start, end = break_at_idx + 1},
						},
					) or_return

					row_start = break_at_idx + 1
					line_height_offset += line_height

					row_width = 0
					for j in row_start ..= i {
						row_width += glyphs[j].metrics.width
					}
				}
			} else {
				row_width += glyphs[i].metrics.width
			}
		}

		append(
			rows,
			Positioned_Row {
				pos = {0, line_height_offset},
				size = {row_width, line_height},
				glyph_range = {start = row_start, end = paragraph.glyph_range.end},
			},
		) or_return
		line_height_offset += line_height
	}
	return nil
}


// TODO(Thomas): We need to think about good allocation strategies here,
// can we get away with an arena, e.g. the frame arena?
// TODO(Thomas): Too much allocation going on here would like to have pre-allocated, upper bounded
// arrays come in instead maybe?
// Don't return an instance of Text_Layout here? Take in ^Text_Layout instead?
// It holds a slice into the rows, which is allocated by the passed in allocator,
// so that lifetime needs to be made explicit and obvious at least.
// TODO(Thomas): Alot of the font stuff and callbacks here could be grouped into something
// somehow.
layout_text :: proc(
	text: string,
	available_width: f32,
	font_handle: Font_Handle,
	text_measurement: Text_Measurement,
	allocator: mem.Allocator,
	text_wrap_mode: Text_Wrap_Mode,
) -> (
	layout: Text_Layout,
	alloc_err: mem.Allocator_Error,
) {

	// TODO(Thomas): This should be cached of course.
	text_metrics := text_measurement.measure_text_proc(
		text,
		font_handle,
		text_measurement.font_user_data,
	)

	// Minimal pipeline for now
	paragraphs := make([dynamic]Paragraph, allocator) or_return
	paragraph_segmentation(text, &paragraphs) or_return

	text_runs := make([dynamic]Text_Run, allocator) or_return
	style_analysis(paragraphs[:], &text_runs) or_return

	glyphs := make([dynamic]Glyph, allocator) or_return

	// TODO(Thomas): Missing passing / retrieving right data types to/from bidi_analysis
	bidi_analysis()

	shaping(
		text,
		paragraphs[:],
		text_runs[:],
		&glyphs,
		text_measurement.measure_codepoint_proc,
		text_measurement.font_user_data,
	) or_return

	// TODO(Thomas): This should probably be done before shaping and on grapheme clusters
	// and not on glyphs
	linebreak_candidates := make([dynamic]Linebreak_Candidate, allocator) or_return
	find_linebreak_candidates(paragraphs[:], glyphs[:], &linebreak_candidates) or_return

	rows := make([dynamic]Positioned_Row, allocator) or_return
	layout_rows(
		paragraphs[:],
		glyphs[:],
		linebreak_candidates[:],
		&rows,
		available_width,
		text_metrics.line_height,
		text_wrap_mode,
	) or_return

	// TODO(Thomas): This could be done in layout_rows instead so we don't have
	// to iterate over the rows again here.
	layout_size := base.Vec2{}
	for row in rows {
		layout_size.x = max(layout_size.x, row.size.x)
		layout_size.y += row.size.y
	}
	return Text_Layout{size = layout_size, rows = rows[:], glyphs = glyphs[:]}, nil
}
