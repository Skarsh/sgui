package ui

import "base:runtime"
import "core:hash"
import "core:mem"

FNV_OFFSET :: 0xcbf29ce484222325

UI_Key :: struct {
	hash: u64,
}

@(require_results)
ui_key_null :: proc() -> UI_Key {
	return UI_Key{hash = 0}
}

@(require_results)
ui_key_current_loc :: proc(seed: u64 = FNV_OFFSET, loc := #caller_location) -> UI_Key {
	h := hash_string(loc.file_path, seed)
	h = hash_u64(u64(loc.line), h)
	h = hash_u64(u64(loc.column), h)

	return UI_Key{hash = h}
}

@(require_results)
ui_key_from_loc :: proc(loc: runtime.Source_Code_Location, seed: u64 = FNV_OFFSET) -> UI_Key {
	h := hash_string(loc.file_path, seed)
	h = hash_u64(u64(loc.line), h)
	h = hash_u64(u64(loc.column), h)

	return UI_Key{hash = h}
}

@(require_results)
hash_string :: proc(str: string, seed: u64 = FNV_OFFSET) -> u64 {
	return hash.fnv64a(transmute([]u8)str, seed)
}

@(require_results)
hash_u64 :: proc(val: u64, seed: u64 = FNV_OFFSET) -> u64 {
	val := val
	bytes := mem.ptr_to_bytes(&val)
	return hash.fnv64a(bytes, seed)
}

@(require_results)
current_id_seed :: proc(ctx: ^Context) -> u64 {
	seed, ok := peek(&ctx.id_stack)
	if !ok {
		seed = FNV_OFFSET
	}
	return seed
}

push_id_int :: proc(ctx: ^Context, i: int) {
	h := hash_u64(u64(i), current_id_seed(ctx))
	push_ok := push(&ctx.id_stack, h)
	assert(push_ok, "id nesting is deeper than ID_STACK_SIZE allows")
}

push_id_string :: proc(ctx: ^Context, id: string) {
	h := hash_string(id, current_id_seed(ctx))
	push_ok := push(&ctx.id_stack, h)
	assert(push_ok, "id nesting is deeper than ID_STACK_SIZE allows")
}

push_id :: proc {
	push_id_int,
	push_id_string,
}

pop_id :: proc(ctx: ^Context) {
	_, pop_ok := pop(&ctx.id_stack)
	assert(pop_ok, "pop_id without a matching push_id")
}
