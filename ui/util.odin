package ui

import "core:hash"

UI_Key :: struct {
	hash: u64,
}

@(require_results)
ui_key_null :: proc() -> UI_Key {
	return UI_Key{hash = 0}
}

// We treat 0 as a strictly reserved sentinel value for "no ID" / "do not cache".
// If a valid non-empty string hashes to 0, we fallback to a non-zero value, e.g. 1.
@(require_results)
ui_key_hash :: proc(str: string, seed: u64 = 0xcbf29ce484222325) -> UI_Key {
	if str == "" {
		return UI_Key{hash = 0}
	}

	h := hash.fnv64a(transmute([]u8)str, seed)

	if h == 0 {
		h = 1
	}

	return UI_Key{hash = h}
}

@(require_results)
ui_key_match :: proc(a, b: UI_Key) -> bool {
	return a.hash == b.hash
}
