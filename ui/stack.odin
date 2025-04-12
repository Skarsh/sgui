package ui

import "core:testing"

Stack :: struct($T: typeid, $N: int) {
	idx:   i32,
	items: [N]T,
}

create_stack :: proc($T: typeid, $N: int) -> Stack(T, N) {
	stack := Stack(T, N){}
	stack.idx = -1
	return stack
}

push :: #force_inline proc(stack: ^$T/Stack($V, $N), val: V) -> bool {
	if stack.idx >= len(stack.items) - 1 {
		return false
	}

	stack.idx += 1
	stack.items[stack.idx] = val

	return true
}


pop :: #force_inline proc(stack: ^$T/Stack($V, $N)) -> (V, bool) {
	val: V = ---

	if stack.idx < 0 {
		return val, false
	}

	val = stack.items[stack.idx]
	stack.idx -= 1
	return val, true
}

peek :: #force_inline proc(stack: ^$T/Stack($V, $N)) -> (V, bool) {
	val: V = ---

	if stack.idx < 0 {
		return val, false
	}

	val = stack.items[stack.idx]
	return val, true
}

is_empty :: proc(stack: ^$T/Stack($V, $N)) -> bool {
	return stack.idx == -1
}

clear :: proc(stack: ^$T/Stack($V, $N)) {
	stack.idx = -1
}

@(test)
test_basic_stack_operations :: proc(t: ^testing.T) {

	N :: 5
	stack := create_stack(int, N)

	// Stack items has length N, so pushing N items
	// onto the stack should be fine
	for i in 0 ..< N {
		ok := push(&stack, i)
		testing.expect(t, ok)
	}

	{
		// Trying to push one more than N, so this should fail
		ok := push(&stack, N + 1)
		testing.expect(t, !ok)

	}

	{
		// Peek
		val, ok := peek(&stack)
		testing.expect(t, ok)
		testing.expect_value(t, val, N - 1)
	}


	// Pop N items off the stack
	for i in 0 ..< N {
		val, ok := pop(&stack)
		testing.expect(t, ok)
		testing.expect_value(t, val, (N - i) - 1)
	}

	{
		// Peek
		_, ok := peek(&stack)
		testing.expect(t, !ok)
	}

	{
		// is_empty
		empty := is_empty(&stack)
		testing.expect(t, empty)
	}

	{
		// clear while empty
		clear(&stack)
		empty := is_empty(&stack)
		testing.expect(t, empty)
	}

	{
		// push some items and then clear, should be empty
		push(&stack, 42)
		empty := is_empty(&stack)
		testing.expect(t, !empty)
		clear(&stack)
		empty = is_empty(&stack)
		testing.expect(t, empty)
	}

}
