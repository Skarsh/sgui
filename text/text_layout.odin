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
	font_id:   int,
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
	codepoint:  rune,
	byte_range: base.Range,
	metrics:    Codepoint_Metrics,
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
	pos:           base.Vec2,
	// The size of the visual content (width without trailing whitespace)
	size:          base.Vec2,
	// The width of the row, counting trailing whitespace
	advance_width: f32,
	glyph_range:   base.Range,
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
	ts: ^Text_System,
	font_id: int,
) -> mem.Allocator_Error {
	glyph_start := 0
	glyph_end := 0
	for &paragraph in paragraphs {
		runs := text_runs[paragraph.text_run_range.start:paragraph.text_run_range.end]
		for run in runs {
			sub := text[run.range.start:run.range.end]
			// TODO(Thomas): We emit one glyph per rune here. Real shaping needs grapheme
			// clusters and ligatures, where runes and glyphs are not one to one.
			for r, i in sub {
				glyph_end += 1

				byte_start := run.range.start + i
				byte_end := byte_start + utf8.rune_size(r)

				codepoint_metrics := glyph_metrics(ts, font_id, r)
				append(
					glyphs,
					Glyph {
						codepoint = r,
						byte_range = {start = byte_start, end = byte_end},
						metrics = codepoint_metrics,
					},
				) or_return
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

// Produces the content_width (the width of the visual content without trailing whitespace),
// and the advance_width (the width of all the glyphs on the row, with trailing whitespace).
@(private)
measure_row_widths :: proc(glyphs: []Glyph) -> (content_width: f32, advance_width: f32) {
	for glyph in glyphs {
		advance_width += glyph.metrics.width
		if !unicode.is_white_space(glyph.codepoint) {
			content_width = advance_width
		}
	}

	return
}

// Sentinel width that means "no width constraint", used when measuring intrinsic size.
// TODO(Thomas): We could use a Maybe(f32) instead, so the no-constraint case is
// enforced by the type instead of a sentinel value.
UNBOUNDED_WIDTH :: max(f32)

@(private)
@(require_results)
calc_aligned_row_x_pos :: proc(
	alignment_x: base.Alignment_X,
	available_width: f32,
	row_width: f32,
) -> f32 {

	// Alignment needs a bounded width to align within. With no width constraint there
	// is no box edge, so we treat it as left aligned.
	if available_width == UNBOUNDED_WIDTH {
		return 0
	}

	row_x: f32
	switch alignment_x {
	case .Left:
	// Do nothing
	case .Center:
		row_x = (available_width - row_width) / 2
	case .Right:
		row_x = available_width - row_width
	}
	return row_x
}


// TODO(Thomas): Epsilon is for f32 accumulation error,
// the proper fix is integer/fixed-point glyph metrics (e.g. FreeType 26.6 or Pango units).
@(private = "file")
DEFAULT_EPSILON :: 0.001

// TODO(Thomas): There are several questions about how this should work for .Truncate
layout_rows_unwrapped :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	rows: ^[dynamic]Positioned_Row,
	available_width: f32,
	line_height: f32,
	alignment_x: base.Alignment_X,
	text_wrap_mode: Text_Wrap_Mode,
	epsilon: f32,
) -> mem.Allocator_Error {
	line_height_offset: f32 = 0
	for paragraph in paragraphs {
		row_width: f32 = 0
		// TODO(Thomas): Use measure_row_widths helper here
		for i in paragraph.glyph_range.start ..< paragraph.glyph_range.end {
			glyph_width := glyphs[i].metrics.width

			// TODO(Thomas): For .Truncate we should stop at first overflow,
			// if not we can end up with adding a later glyph that actually fits, which
			// most definitely is unintended behaviour.
			if text_wrap_mode == .None || row_width + glyph_width <= available_width + epsilon {
				row_width += glyph_width
			}
		}

		row_x := calc_aligned_row_x_pos(alignment_x, available_width, row_width)
		append(
			rows,
			Positioned_Row {
				pos = {row_x, line_height_offset},
				size = {row_width, line_height},
				advance_width = row_width,
				glyph_range = paragraph.glyph_range,
			},
		) or_return

		line_height_offset += line_height
	}
	return nil
}

layout_rows_wrapped :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: []Linebreak_Candidate,
	rows: ^[dynamic]Positioned_Row,
	available_width: f32,
	line_height: f32,
	alignment_x: base.Alignment_X,
	epsilon: f32,
) -> mem.Allocator_Error {

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

			if row_width + glyph.metrics.width > available_width + epsilon {
				break_at_idx: int
				if break_candidate_idx >= row_start {
					break_at_idx = break_candidate_idx
				} else {
					break_at_idx = max(i - 1, row_start)
				}

				// Find the row widths
				content_width, advance_width := measure_row_widths(
					glyphs[row_start:break_at_idx + 1],
				)

				row_x := calc_aligned_row_x_pos(alignment_x, available_width, content_width)
				append(
					rows,
					Positioned_Row {
						pos = {row_x, line_height_offset},
						size = {content_width, line_height},
						advance_width = advance_width,
						glyph_range = {start = row_start, end = break_at_idx + 1},
					},
				) or_return

				row_start = break_at_idx + 1
				line_height_offset += line_height

				row_width = 0
				for j in row_start ..= i {
					row_width += glyphs[j].metrics.width
				}
			} else {
				row_width += glyph.metrics.width
			}
		}

		content_width, advance_width := measure_row_widths(
			glyphs[row_start:paragraph.glyph_range.end],
		)

		row_x := calc_aligned_row_x_pos(alignment_x, available_width, content_width)
		append(
			rows,
			Positioned_Row {
				pos = {row_x, line_height_offset},
				size = {content_width, line_height},
				advance_width = advance_width,
				glyph_range = {start = row_start, end = paragraph.glyph_range.end},
			},
		) or_return

		line_height_offset += line_height
	}
	return nil
}

layout_rows :: proc(
	paragraphs: []Paragraph,
	glyphs: []Glyph,
	linebreak_candidates: []Linebreak_Candidate,
	rows: ^[dynamic]Positioned_Row,
	available_width: f32,
	line_height: f32,
	alignment_x: base.Alignment_X,
	text_wrap_mode: Text_Wrap_Mode,
	epsilon: f32 = DEFAULT_EPSILON,
) -> mem.Allocator_Error {
	switch text_wrap_mode {
	case .None, .Truncate:
		layout_rows_unwrapped(
			paragraphs,
			glyphs,
			rows,
			available_width,
			line_height,
			alignment_x,
			text_wrap_mode,
			epsilon,
		) or_return
	case .Wrap:
		layout_rows_wrapped(
			paragraphs,
			glyphs,
			linebreak_candidates,
			rows,
			available_width,
			line_height,
			alignment_x,
			epsilon,
		) or_return
	}
	return nil
}

Text_Layout_Params :: struct {
	available_width: f32,
	font_id:         int,
	alignment_x:     base.Alignment_X,
	wrap_mode:       Text_Wrap_Mode,
}


// TODO(Thomas): We need to think about good allocation strategies here,
// can we get away with an arena, e.g. the frame arena?
// TODO(Thomas): Too much allocation going on here would like to have pre-allocated, upper bounded
// arrays come in instead maybe?
// Don't return an instance of Text_Layout here? Take in ^Text_Layout instead?
// It holds a slice into the rows, which is allocated by the passed in allocator,
// so that lifetime needs to be made explicit and obvious at least.
layout_text :: proc(
	ts: ^Text_System,
	text: string,
	params: Text_Layout_Params,
	persistent_allocator: mem.Allocator,
	frame_allocator: mem.Allocator,
) -> (
	layout: Text_Layout,
	alloc_err: mem.Allocator_Error,
) {

	// Minimal pipeline for now
	paragraphs := make([dynamic]Paragraph, frame_allocator) or_return
	paragraph_segmentation(text, &paragraphs) or_return

	text_runs := make([dynamic]Text_Run, frame_allocator) or_return
	style_analysis(paragraphs[:], &text_runs) or_return

	glyphs := make([dynamic]Glyph, persistent_allocator) or_return

	// TODO(Thomas): Missing passing / retrieving right data types to/from bidi_analysis
	bidi_analysis()

	shaping(text, paragraphs[:], text_runs[:], &glyphs, ts, params.font_id) or_return

	// TODO(Thomas): This should probably be done before shaping and on grapheme clusters
	// and not on glyphs
	linebreak_candidates := make([dynamic]Linebreak_Candidate, frame_allocator) or_return
	find_linebreak_candidates(paragraphs[:], glyphs[:], &linebreak_candidates) or_return

	rows := make([dynamic]Positioned_Row, persistent_allocator) or_return
	// TODO(Thomas): Do more error handling here if line height is not ok?
	line_height, line_height_ok := font_line_height(ts, params.font_id)
	assert(line_height_ok)
	layout_rows(
		paragraphs[:],
		glyphs[:],
		linebreak_candidates[:],
		&rows,
		params.available_width,
		line_height,
		params.alignment_x,
		params.wrap_mode,
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

@(require_results)
text_layout_byte_pos_from_point :: proc(layout: Text_Layout, pos: base.Vec2) -> (byte_pos: int) {

	// Outline of the algorithm
	// Find y-offset / row that is closest to the pos.y
	// Find subslice of the row without trailing newline if there is any
	// Then walk the row to find the glyph that is closest to pos.x
	// Resolve whether to put byte pos on the start or end of the last glyph.

	if len(layout.rows) > 0 {
		// Find the closest row
		row_idx := len(layout.rows) - 1
		for row, i in layout.rows {
			if pos.y < row.pos.y + row.size.y {
				row_idx = i
				break
			}
		}

		// Find glyphs that are hittable, meaning remove trailing newline glyphs
		// since hit testing against them will not result in wanted byte pos.
		row := layout.rows[row_idx]
		row_glyphs := base.slice_from_range(layout.glyphs, row.glyph_range)
		// A trailing newline is a line boundary, so exclude it and the caret stays on this line.
		hit_glyphs := row_glyphs
		row_len := len(row_glyphs)
		if row_len > 0 {
			if row_glyphs[row_len - 1].codepoint == '\n' {
				hit_glyphs = row_glyphs[:row_len - 1]
			}

			// Walk the glyphs left to right and snap to whichever side of a glyph pos.x is closest to
			cursor_x := row.pos.x
			for glyph in hit_glyphs {
				// Using glyph.metrics.width / 2 to find which side of the glyph is closest
				if pos.x < cursor_x + glyph.metrics.width / 2 {
					return glyph.byte_range.start
				} else {
					cursor_x += glyph.metrics.width
				}
			}

			// pos.x is past the last hit glyph, so the caret goes to the line end
			if len(hit_glyphs) < row_len {
				// Byte pos is placed before the trailing newline, if there was any
				byte_pos = row_glyphs[row_len - 1].byte_range.start
			} else {
				// No trailing newline, byte pos is at the end.
				byte_pos = row_glyphs[row_len - 1].byte_range.end
			}
		}
	}

	return
}

@(require_results)
text_layout_caret_pos :: proc(
	layout: Text_Layout,
	byte_pos: int,
) -> (
	pos: base.Vec2,
	height: f32,
) {

	rows := layout.rows
	row_len := len(rows)
	if row_len > 0 {
		// Pick the row where the caret range holds byte_pos, clamping at the last row
		row_idx := row_len - 1

		// We find which row the byte_pos is in by checking against the byte_pos of the
		// last glyph, with handling of whether it's a trailing newline or not.
		for row, i in rows {
			row_glyphs := base.slice_from_range(layout.glyphs, row.glyph_range)

			caret_end := 0
			row_glyphs_len := len(row_glyphs)
			if row_glyphs_len > 0 {
				last := row_glyphs[row_glyphs_len - 1]
				if last.codepoint == '\n' {
					caret_end = last.byte_range.start
				} else {
					caret_end = last.byte_range.end
				}
			}

			// We know that since byte_pos <= caret_end, byte_pos must be on this row.
			if byte_pos <= caret_end {
				row_idx = i
				break
			}
		}

		row := rows[row_idx]

		// Walk the glyphs left-to-right, to the caret x position
		caret_x := row_x_at_byte(
			base.slice_from_range(layout.glyphs, row.glyph_range),
			row.pos.x,
			byte_pos,
		)

		return {caret_x, row.pos.y}, row.size.y
	}

	return
}

@(private = "file")
@(require_results)
row_x_at_byte :: proc(row_glyphs: []Glyph, row_x: f32, byte_pos: int) -> f32 {
	x := row_x
	for glyph in row_glyphs {
		if byte_pos <= glyph.byte_range.start {
			break
		}
		x += glyph.metrics.width
	}
	return x
}

// Only a non-collapsed selection is meaningful
@(require_results)
text_layout_row_selection_rect :: proc(
	layout: Text_Layout,
	row: Positioned_Row,
	selection: Selection,
) -> base.Rect_F32 {

	sel_start := selection_start(selection)
	sel_end := selection_end(selection)

	if sel_start != sel_end {
		row_glyphs := base.slice_from_range(layout.glyphs, row.glyph_range)
		row_glyphs_len := len(row_glyphs)

		if row_glyphs_len > 0 {
			row_start_byte := row_glyphs[0].byte_range.start
			last := row_glyphs[row_glyphs_len - 1]
			row_caret_end := last.byte_range.end

			// If the last glyph is a trailing newline, we put the caret right before it
			if last.codepoint == '\n' {
				row_caret_end = last.byte_range.start
			}

			// Clip the selection to the row byte span
			lo := max(sel_start, row_start_byte)
			hi := min(sel_end, row_caret_end)

			if lo < hi {
				x_lo := row_x_at_byte(row_glyphs, row.pos.x, lo)
				x_hi := row_x_at_byte(row_glyphs, row.pos.x, hi)

				return base.Rect_F32{x = x_lo, y = row.pos.y, w = x_hi - x_lo, h = row.size.y}
			}
		}
	}

	return {}
}

@(require_results)
measure_text_intrinsic :: proc(text: string, ts: ^Text_System, font_id: int) -> base.Vec2 {

	size := base.Vec2{}
	if len(text) > 0 {

		// TODO(Thomas): Do more error handling here when the line hegiht is not ok?
		line_height, line_height_ok := font_line_height(ts, font_id)
		assert(line_height_ok)

		row_width: f32

		for r in text {
			cm := glyph_metrics(ts, font_id, r)

			row_width += cm.width

			if r == '\n' {
				size.x = max(size.x, row_width)
				size.y += line_height
				row_width = 0
			}
		}

		// Final line if the text didn't end with a newline
		if row_width > 0 {
			size.x = max(size.x, row_width)
			size.y += line_height
		}
	}

	return size
}
