package ui

UI_Key :: struct {
	hash: u64,
}

ui_key_null :: proc() -> UI_Key {
	return UI_Key{hash = 0}
}

ui_key_hash :: proc(str: string) -> UI_Key {
	hash: u64 = 5381

	for b in transmute([]u8)str {
		hash = ((hash << 5) + hash) + u64(b)
	}

	return UI_Key{hash = hash}
}

ui_key_match :: proc(a, b: UI_Key) -> bool {
	return a.hash == b.hash
}

intersect_rect :: proc(ctx: Context, rect: Rect) -> bool {
	if ctx.input.mouse_pos.x < rect.x ||
	   ctx.input.mouse_pos.y < rect.y ||
	   ctx.input.mouse_pos.x >= rect.x + rect.w ||
	   ctx.input.mouse_pos.y >= rect.y + rect.h {
		return false
	}
	return true
}
