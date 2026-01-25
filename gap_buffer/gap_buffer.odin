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

// Move the gap left
left :: proc(gb: ^Gap_Buffer) {
	shift_gap_to(gb, gb.start - 1)
}

// Move the gap right
right :: proc(gb: ^Gap_Buffer) {
	shift_gap_to(gb, gb.start + 1)
}

// TODO(Thomas): Add more insert procs, insert_slice, insert_rune, insert_string etc.
insert :: proc(gb: ^Gap_Buffer, ch: u8) {
	if gb.start == gb.end {
		// grow
	}
	gb.buf[gb.start] = ch
	gb.start += 1
}

delete :: proc(gb: ^Gap_Buffer) {
	if gb.start != 0 {
		gb.start -= 1
	}
}

// Helper procedure to get the left and right strings of the gap
@(private)
get_strings :: proc(gb: ^Gap_Buffer) -> (left: string, right: string) {
	left = string(gb.buf[0:gb.start])
	right = string(gb.buf[gb.end:])
	return
}

// Grows the buffer when out of space
@(private)
grow :: proc(gb: ^Gap_Buffer) {
}


// TODO(Thomas): Make this use mem.copy for large jumps?
// Shifts the gap to position given in the buf
@(private)
shift_gap_to :: proc(gb: ^Gap_Buffer, pos: int) {
	// pos must be withing the size of buf, and not the same as gb.start
	if pos < 0 || pos < len(gb.buf) && gb.start != pos {

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
			gb.buf[gb.end] = gb.buf[gb.start]
			gb.start -= 1
			gb.end -= 1
		}
	}
}

main :: proc() {
	gb := make_gap_buffer(16)

	insert(&gb, 'k')
	insert(&gb, 'e')
	insert(&gb, 'k')

	delete(&gb)
	insert(&gb, 'l')

	left, right := get_strings(&gb)
	fmt.println("gb: ", gb)
	fmt.println("left: ", left)
	fmt.println("right: ", right)
}


@(test)
test_it_works :: proc(t: ^testing.T) {
	testing.expect(t, true)
}
