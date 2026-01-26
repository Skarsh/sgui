package gap_buffer

import "core:fmt"
import "core:log"
import "core:mem"
import "core:testing"

Gap_Buffer :: struct {
	buf:       []u8,
	start:     int,
	end:       int,
	allocator: mem.Allocator,
}

make_gap_buffer :: proc(size: int, allocator := context.allocator) -> Gap_Buffer {
	gb := Gap_Buffer {
		buf       = make([]u8, size, allocator),
		start     = 0,
		end       = size,
		allocator = allocator,
	}
	return gb
}

to_string :: proc(gb: ^Gap_Buffer) -> (str: string) {
	left, right := get_strings(gb^)
	str = fmt.tprintf("%s%s", left, right)
	return
}

// TODO(Thomas): Add more insert procs, insert_slice, insert_rune, insert_string etc.
insert_char :: proc(gb: ^Gap_Buffer, pos: int, ch: u8) {
	if pos >= 0 && pos <= length(gb^) {

		if gb.start == gb.end {
			// grow
			grow(gb, 1)
		}

		shift_gap_to(gb, pos)

		gb.buf[gb.start] = ch
		gb.start += 1
	}
}

delete_char :: proc(gb: ^Gap_Buffer, pos: int) {
	if pos >= 0 && pos < length(gb^) {
		shift_gap_to(gb, pos)
		gb.end += 1
	}
}


length :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf) - (gb.end - gb.start)
}

capacity :: proc(gb: Gap_Buffer) -> int {
	return len(gb.buf)
}

gap_size :: proc(gb: Gap_Buffer) -> int {
	return gb.end - gb.start
}

// Helper procedure to get the left and right strings of the gap
@(private)
get_strings :: proc(gb: Gap_Buffer) -> (left: string, right: string) {
	left = string(gb.buf[0:gb.start])
	right = string(gb.buf[gb.end:])
	return
}

// Grows the buffer when out of space
@(private)
grow :: proc(gb: ^Gap_Buffer, required: int) {
	// The capacity we need to fit
	needed_cap := len(gb.buf) + required

	// We go for a default strategy of doubling the buffer, unless
	// the required amount is larger than the double, then we use the required.
	new_cap := max(2 * len(gb.buf), needed_cap)

	amount_grown := new_cap - len(gb.buf)
	new_buf := make([]u8, new_cap, gb.allocator)
	// Now we need to move the gap end to the end.
	// abecdefghi
	//     ^^
	// We grow
	// abed__________efghi
	//    ^          ^
	// So the gap end has to move by the amount we've grown.
	old_end := gb.end
	gb.end += amount_grown

	copy_slice(new_buf[:gb.start], gb.buf[:gb.start])
	copy_slice(new_buf[gb.end:], gb.buf[old_end:])

	delete(gb.buf)
	gb.buf = new_buf
}


// Shifts the gap to position given in the buf
@(private)
shift_gap_to :: proc(gb: ^Gap_Buffer, pos: int) {
	// pos must be within the size of buf, and not the same as gb.start
	if pos >= 0 && pos < len(gb.buf) && gb.start != pos {

		// Before moving 1 right
		// abcd____efgh
		//    ^    ^

		// After moving 1 right
		// abcde____fgh
		//     ^    ^

		// Moving gap right, so need to copy chars to the left
		for gb.start < pos {
			gb.buf[gb.start] = gb.buf[gb.end]
			gb.start += 1
			gb.end += 1
		}

		// Before moving 1 left
		// abcd____efgh
		//    ^    ^

		// After moving 1 left
		// abc____defgh
		//   ^    ^

		// Moving gap left, so need to copy chars to the right
		for pos < gb.start {
			gb.start -= 1
			gb.end -= 1
			gb.buf[gb.end] = gb.buf[gb.start]
		}
	}
}

main :: proc() {
	gb := make_gap_buffer(16)

	insert_char(&gb, 0, '1')
	insert_char(&gb, 1, '2')
	delete_char(&gb, 0)


	left, right := get_strings(gb)
	fmt.println("gb: ", gb)
	fmt.println("left: ", left)
	fmt.println("right: ", right)
}


@(test)
test_insert_and_delete_char :: proc(t: ^testing.T) {
	gb := make_gap_buffer(16)
	defer delete(gb.buf)
	insert_char(&gb, 0, '1')
	str := to_string(&gb)
	testing.expect_value(t, str, "1")

	delete_char(&gb, 0)
	str = to_string(&gb)
	testing.expect_value(t, str, "")
}
