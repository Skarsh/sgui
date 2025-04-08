package ui

KeymodFlag :: enum u16 {
	LSHIFT   = 0x0,
	RSHIFT   = 0x1,
	LCTRL    = 0x6,
	RCTRL    = 0x7,
	LALT     = 0x8,
	RALT     = 0x9,
	LGUI     = 0xa,
	RGUI     = 0xb,
	NUM      = 0xc,
	CAPS     = 0xd,
	MODE     = 0xe,
	RESERVED = 0xf,
}

Keymod :: distinct bit_set[KeymodFlag;u16]

KMOD_NONE :: Keymod{}
KMOD_LSHIFT :: Keymod{.LSHIFT}
KMOD_RSHIFT :: Keymod{.RSHIFT}
KMOD_LCTRL :: Keymod{.LCTRL}
KMOD_RCTRL :: Keymod{.RCTRL}
KMOD_LALT :: Keymod{.LALT}
KMOD_RALT :: Keymod{.RALT}
KMOD_LGUI :: Keymod{.LGUI}
KMOD_RGUI :: Keymod{.RGUI}
KMOD_NUM :: Keymod{.NUM}
KMOD_CAPS :: Keymod{.CAPS}
KMOD_MODE :: Keymod{.MODE}
KMOD_RESERVED :: Keymod{.RESERVED}
KMOD_CTRL :: Keymod{.LCTRL, .RCTRL}
KMOD_SHIFT :: Keymod{.LSHIFT, .RSHIFT}
KMOD_ALT :: Keymod{.LALT, .RALT}
KMOD_GUI :: Keymod{.LGUI, .RGUI}


// These are taken from SDL3 keycodes https://wiki.libsdl.org/SDL3/SDL_Keycode
Key :: enum {
	Unknown,
	Return,
	Escape,
	Backspace,
	Tab,
	Space,
	Exclaim,
	Dbl_Apostrophe,
	Hash,
	Dollar,
	Ampersand,
	Apsotrohe,
	Left_Paren,
	Right_Paren,
	Asterisk,
	Plus,
	Comma,
	Minus,
	Period,
	Slash,
	Num_0,
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,
	Colon,
	Semicolon,
	Less,
	Equals,
	Greater,
	Question,
	At,
	Left_Bracket,
	Back_Slash,
	Right_Bracket,
	Caret,
	Underscore,
	Grave,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	Left_Brace,
	Pipe,
	Right_Brace,
	Tilde,
	Delete,
	Plus_Minus,
	Capslock,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	// Continue here
}
