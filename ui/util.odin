package ui

hash_key :: proc(str: string) -> u64 {
	hash: u64 = 5381

	for b in transmute([]u8)str {
		hash = ((hash << 5) + hash) + u64(b)
	}

	return hash
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
