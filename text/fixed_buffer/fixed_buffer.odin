package fixed_buffer

import "core:testing"

Fixed_Buffer :: struct {
	buf: []u8,
	len: int,
}

init :: proc(buf: []u8) -> Fixed_Buffer {
	return Fixed_Buffer{buf = buf, len = 0}
}

init_with_content :: proc(buf: []u8, content: []u8) -> Fixed_Buffer {
	assert(len(content) <= len(buf))
	n := min(len(buf), len(content))
	copy(buf[:n], content[:n])
	return Fixed_Buffer{buf = buf, len = n}
}

capacity :: proc(fb: Fixed_Buffer) -> int {
	return len(fb.buf)
}

remaining :: proc(fb: Fixed_Buffer) -> int {
	return len(fb.buf) - fb.len
}

contents :: proc(fb: Fixed_Buffer) -> []u8 {
	return fb.buf[:fb.len]
}

insert_slice :: proc(fb: ^Fixed_Buffer, pos: int, bytes: []u8) -> bool {
	if pos < 0 || pos > fb.len do return false
	if len(bytes) > remaining(fb^) do return false

	// Shift existing data right
	copy(fb.buf[pos + len(bytes):], fb.buf[pos:fb.len])

	// Insert new data
	copy(fb.buf[pos:], bytes)
	fb.len += len(bytes)

	return true
}

insert_byte_at :: proc(fb: ^Fixed_Buffer, pos: int, b: u8) -> bool {
	return insert_slice(fb, pos, {b})
}

delete :: proc(fb: ^Fixed_Buffer, pos: int, count: int) -> bool {
	if pos < 0 || count < 0 || pos + count > fb.len do return false

	copy(fb.buf[pos:], fb.buf[pos + count:fb.len])
	fb.len -= count

	return true
}

clear :: proc(fb: ^Fixed_Buffer) {
	fb.len = 0
}

byte_at :: proc(fb: Fixed_Buffer, pos: int) -> (u8, bool) {
	if pos < 0 || pos >= fb.len {
		return 0, false
	}
	return fb.buf[pos], true
}

@(test)
test_init :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := init(backing[:])

	testing.expect_value(t, fb.len, 0)
	testing.expect_value(t, capacity(fb), N)
}

@(test)
test_init_with_content :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	content := "hello"
	fb := init_with_content(backing[:], transmute([]u8)content)
	testing.expect_value(t, fb.len, len(content))
	testing.expect_value(t, capacity(fb), N)
	testing.expect_value(t, string(contents(fb)), "hello")
}

@(test)
test_insert_slice :: proc(t: ^testing.T) {
	N :: 16
	backing: [N]u8
	fb := init(backing[:])

	testing.expect(t, insert_slice(&fb, 0, transmute([]u8)string("hello")))
	testing.expect_value(t, string(contents(fb)), "hello")

	testing.expect(t, insert_slice(&fb, 5, transmute([]u8)string(" world")))
	testing.expect_value(t, string(contents(fb)), "hello world")

	testing.expect(t, insert_slice(&fb, 5, transmute([]u8)string(",")))
	testing.expect_value(t, string(contents(fb)), "hello, world")
}
