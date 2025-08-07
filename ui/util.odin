package ui

UI_Key :: struct {
	hash: u64,
}

@(require_results)
ui_key_null :: proc() -> UI_Key {
	return UI_Key{hash = 0}
}

@(require_results)
ui_key_hash :: proc(str: string) -> UI_Key {
	hash: u64 = 5381

	for b in transmute([]u8)str {
		hash = ((hash << 5) + hash) + u64(b)
	}

	return UI_Key{hash = hash}
}

@(require_results)
ui_key_match :: proc(a, b: UI_Key) -> bool {
	return a.hash == b.hash
}
