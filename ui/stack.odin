package ui

import "core:testing"

Stack :: struct($T: typeid, $N: int) {
	top:   i32,
	items: [N]T,
}


push :: #force_inline proc(stack: ^$T/Stack($V, $N), val: V) -> bool {
	if stack.top + 1 >= len(stack.items) {
		return false
	}

	stack.top += 1
	stack.items[stack.top] = val
	return true
}


pop :: #force_inline proc(stack: ^$T/Stack($V, $N)) -> (V, bool) {
	if stack.top <= 0 {
		return V{}, false
	}
	stack.top -= 1
	return stack.items[stack.top + 1], true
}

peek :: #force_inline proc(stack: ^$T/Stack($V, $N)) -> (V, bool) {
	if stack.top <= 0 {
		return V{}, false
	}

	return stack.items[stack.top], true
}

is_empty :: proc(stack: ^$T/Stack($V, $N)) -> bool {
	return stack.top == 0
}

clear :: proc(stack: ^$T/Stack($V, $N)) {
	stack.top = 0
}

@(test)
test_basic_stack_operations :: proc(t: ^testing.T) {

	stack := Stack(i32, 5){}

	// Check that the stack is empty
	testing.expect(t, is_empty(&stack))

	// Peek should return false when empty
	peek_val, peek_ok := peek(&stack)
	testing.expect(t, !peek_ok)

	// Fill the stack
	push_ok := push(&stack, 1)
	testing.expect(t, push_ok)
	push_ok = push(&stack, 2)
	testing.expect(t, push_ok)
	push_ok = push(&stack, 3)
	testing.expect(t, push_ok)
	push_ok = push(&stack, 4)
	testing.expect(t, push_ok)

	// Try to push one more item onto the stack than the length allows
	push_ok = push(&stack, 5)
	testing.expect(t, !push_ok)

	// Test peek
	peek_val, peek_ok = peek(&stack)
	testing.expect(t, peek_ok)
	testing.expect_value(t, peek_val, 4)


	// Pop all the items
	val, pop_ok := pop(&stack)
	testing.expect(t, pop_ok)
	testing.expect_value(t, val, 4)

	val, pop_ok = pop(&stack)
	testing.expect(t, pop_ok)
	testing.expect_value(t, val, 3)

	val, pop_ok = pop(&stack)
	testing.expect(t, pop_ok)
	testing.expect_value(t, val, 2)

	val, pop_ok = pop(&stack)
	testing.expect(t, pop_ok)
	testing.expect_value(t, val, 1)

	// All items popped, stack is empty
	val, pop_ok = pop(&stack)
	testing.expect(t, !pop_ok)
	testing.expect(t, is_empty(&stack))

	// Push one item onto stack and then clear
	push_ok = push(&stack, 1)
	clear(&stack)
	testing.expect(t, is_empty(&stack))
}
