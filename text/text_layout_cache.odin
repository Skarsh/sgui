package text

Text_Layout_Cache_Request :: struct {
	key:       u64,
	frame_idx: u64,
	text:      string,
	params:    Text_Layout_Params,
}

Text_Layout_Cache_Entry :: struct {
	text_hash: u64,
	params:    Text_Layout_Params,
	layout:    Text_Layout,
}
