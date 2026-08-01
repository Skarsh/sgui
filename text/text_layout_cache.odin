package text

// Core idea:
// Receive layout cache request
// Retreive cache entry from the cache using the cache request key
// If non entry found, calculate new text layout using the cache request and insert a new entry
// If entry is found, compare against all non-key cache request parameters to see if it's
// a different request.
// If request is different, calculate new layout and insert entry for that key

Text_Layout_Cache_Request :: struct {
	key:    u64,
	text:   string,
	params: Text_Layout_Params,
	// TODO(Thomas): Not sure about this one
	//text_measurement: Text_Measurement,
}

Text_Layout_Cache_Entry :: struct {
	cache_request: Text_Layout_Cache_Request,
	text_layout:   Text_Layout,
}

get_text_layout_cache :: proc(cache: ^map[u64]Text_Layout_Cache_Entry) -> Text_Layout {
	return Text_Layout{}
}
