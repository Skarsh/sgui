package ui

import "core:log"
import "core:testing"

Size_Kind :: enum {
	None,
	Pixels,
	Text_Content,
	Percent_Of_Parent,
	Children_Sum,
}

Size :: struct {
	kind:       Size_Kind,
	value:      f32,
	strictness: f32,
}

Axis2 :: enum {
	X,
	Y,
}

Axis2_Size :: len(Axis2)

Widget :: struct {
	// tree links
	next:                  ^Widget,
	prev:                  ^Widget,
	parent:                ^Widget,
	semantic_size:         [Axis2_Size]Size,

	// recomputed every frame
	computed_rel_position: [Axis2_Size]f32,
	computed_size:         [Axis2_Size]f32,
	// NOTE(Thomas): Not entirely sure about this rect
	// and how it should be represented.
	rect:                  Rect,
}

widget_make :: proc(ctx: ^Context, key_id: string) {}

push_parent :: proc(ctx: ^Context, widget: ^Widget) {}

pop_parent :: proc(ctx: ^Context) {}

@(test)
test_widget_hierarchy_creation :: proc(t: ^testing.T) {

}
