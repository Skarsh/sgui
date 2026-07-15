package text

import "core:testing"

import gap_buffer "../gap_buffer"
import fixed_buffer "fixed_buffer"

Test_Backend :: enum {
	Gap,
	Fixed,
}

TEST_BACKENDS :: [?]Test_Backend{.Gap, .Fixed}

TEST_BUFFER_CAP :: 64

// Test only helper to make a Text_Buffer, getting initialized with the provided text.
@(private)
test_text_buffer :: proc(backend: Test_Backend, text: string) -> Text_Buffer {
	tb: Text_Buffer
	switch backend {
	case .Gap:
		gb := gap_buffer.Gap_Buffer{}
		alloc_err := gap_buffer.init_gap_buffer(&gb, TEST_BUFFER_CAP, context.temp_allocator)
		assert(alloc_err == .None)
		tb = Text_Buffer {
			buf = gb,
		}
	case .Fixed:
		storage, alloc_err := make([]u8, TEST_BUFFER_CAP, context.temp_allocator)
		assert(alloc_err == .None)
		tb = Text_Buffer {
			buf = fixed_buffer.Fixed_Buffer{buf = storage},
		}
	}

	insert_err := text_buffer_insert_at(&tb, 0, text)
	assert(insert_err == nil)

	return tb
}

// Test only helper to check insert error
@(private)
text_buffer_insert_ok :: proc(
	t: ^testing.T,
	tb: ^Text_Buffer,
	pos: int,
	val: $T,
	loc := #caller_location,
) {
	tb_err := text_buffer_insert_at(tb, pos, val)
	testing.expect_value(t, tb_err, nil, loc)
}

// Checks that inserting into initial at pos yields expected on every backend.
@(private)
check_insert :: proc(
	t: ^testing.T,
	initial: string,
	pos: int,
	insertion: string,
	expected: string,
	loc := #caller_location,
) {
	for backend in TEST_BACKENDS {
		tb := test_text_buffer(backend, initial)

		insert_err := text_buffer_insert_at(&tb, pos, insertion)
		testing.expectf(
			t,
			insert_err == nil,
			"[%v] inserting %q at %v into %q: expected success, got %v",
			backend,
			insertion,
			pos,
			initial,
			insert_err,
			loc = loc,
		)

		actual, alloc_err := text_buffer_text(tb, context.temp_allocator)
		assert(alloc_err == .None)
		testing.expectf(
			t,
			actual == expected,
			"[%v] inserting %q at %v into %q: expected %q, got %q",
			backend,
			insertion,
			pos,
			initial,
			expected,
			actual,
			loc = loc,
		)
	}
}
