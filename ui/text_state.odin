package ui

import textpkg "../text"

// Returns the text state for the given key. Creates it from the specified variant when
// the there is no hit on the key. Also stamps the last_frame_idx to the current frame_idx.
@(require_results)
text_state_for :: proc(
	ctx: ^Context,
	key: UI_Key,
	variant: textpkg.Text_State_Variant,
) -> ^textpkg.Text_State {

	state, found := &ctx.text_system.text_states[key.hash]
	if !found {
		state = map_insert(
			&ctx.text_system.text_states,
			key.hash,
			textpkg.Text_State{variant = variant},
		)
	}
	state.last_frame_idx = ctx.frame_idx
	return state
}

@(private)
@(require_results)
focused_text_state :: proc(
	interaction: ^Interaction,
	ts: ^textpkg.Text_System,
) -> (
	^textpkg.Text_State,
	bool,
) {
	// Callers check that something is focused before asking
	return &ts.text_states[interaction.focused_id.hash]
}

@(require_results)
get_text_state_selection :: proc(
	ts: ^textpkg.Text_System,
	element: UI_Element,
) -> (
	textpkg.Selection,
	bool,
) {

	if s, ok := ts.text_states[element.key.hash]; ok {
		return s.selection, true
	}

	return {}, false
}

@(require_results)
focused_caret :: proc(ts: ^textpkg.Text_System, key: UI_Key) -> (byte_pos: int, ok: bool) {
	s, found := ts.text_states[key.hash]
	if found {
		byte_pos = s.selection.active
		ok = true
	}
	return
}
