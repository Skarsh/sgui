package text

// Text layout works in the element / widget space, e.g.
// the constraints on how to layout the text is defined
// by the size of the widget / element the text is attached to.

Token_Kind :: enum u8 {
	Word,
	Whitespace,
	Newline,
}

Text_Token :: struct {
	start:  int, // Byte start in original string
	length: int, // Length of the token in bytes
	width:  f32, // Measured width
	kind:   Token_Kind,
}

Text_Line :: struct {
	text:   string,
	start:  int, // Starting token idx
	length: int, // Length in number of tokens
	width:  f32, // Visual width
	height: f32, // Line height
}


Text_Layout :: struct {
	// Source reference, for cache validation
	text_hash:       u64,
	available_width: f32,
	font_id:         u16,

	// Tokenization results (cached)
	tokens:          [dynamic]Text_Token,

	// Line layouts
	lines:           [dynamic]Text_Line,
}

Text_Layout_Cache :: struct {}
