package ui

hash_key :: proc(str: string) -> u64 {
	hash: u64 = 5381
	c: i32

	for b in transmute([]u8)str {
		hash = ((hash << 5) + hash) + u64(b)
	}

	return hash
}
