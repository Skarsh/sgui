package ui

import "core:log"
import "core:testing"

Widget_Flag :: enum u32 {
	Clickable,
	View_Scroll,
	Draw_Text,
	Draw_Border,
	Draw_Background,
	Draw_Drop_Shadow,
	Clip,
	Hot_Animation,
	Active_Animation,
}

Widget_Flag_Set :: distinct bit_set[Widget_Flag;u16]

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
	first:                 ^Widget,
	last:                  ^Widget,
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

widget_make :: proc(ctx: ^Context, key_id: string) -> (^Widget, bool) {
	widget, err := new(Widget)
	if err != nil {
		log.error("failed to allocated widget")
		return nil, false
	}

	// Set parent
	widget.parent = ctx.current_parent

	// Add to parent's child list if we have a parent
	if widget.parent != nil {
		if widget.parent.first == nil {
			widget.parent.first = widget
			widget.parent.last = widget
		} else {
			widget.parent.last.next = widget
			widget.prev = widget.parent.last
			widget.parent.last = widget
		}
	}

	return widget, true
}

// Push a new widget to become the parent
push_parent :: proc(ctx: ^Context, widget: ^Widget) -> (^Widget, bool) {
	prev_parent := ctx.current_parent
	ok := push(&ctx.parent_list, prev_parent)
	if !ok {
		log.error("Failed to push parent onto parent stack / list")
		return nil, false
	}

	ctx.current_parent = widget

	return prev_parent, true
}

pop_parent :: proc(ctx: ^Context) -> (^Widget, bool) {

	popped_parent := ctx.current_parent

	parent_from_stack, ok := pop(&ctx.parent_list)
	if !ok {
		return nil, false
	}

	ctx.current_parent = parent_from_stack

	return popped_parent, true
}

@(test)
test_widget_hierarchy :: proc(t: ^testing.T) {
	// Initialize context
	ctx := Context{}
	init(&ctx)

	root, ok := widget_make(&ctx, "root")
	testing.expect(t, ok, "Root widget should be created successfully")
	testing.expect(t, root != nil, "Root widget should be created successfully")

	// Push root as parent
	prev, root_push_ok := push_parent(&ctx, root)
	testing.expect(t, root_push_ok, "Should successfully push root as parent")
	testing.expect(t, prev == nil, "Previous parent should be nil")
	testing.expect(t, ctx.current_parent == root, "Container's parent should be root")

	// Create child widgets
	child_1, child_1_ok := widget_make(&ctx, "child_1")
	child_2, child_2_ok := widget_make(&ctx, "child_2")

	testing.expect(t, child_1_ok, "Child_1 widget should be created successfully")
	testing.expect(t, child_1.parent == root, "Child_1's parent should be root")
	testing.expect(t, root.first == child_1, "Root's first child should be child_1")
	testing.expect(t, child_1.prev == nil, "Child_1's prev should be nil")
	testing.expect(t, child_1.next == child_2, "Child_2's next should be child_2")

	testing.expect(t, child_2_ok, "Child_2 widget should be created successfully")
	testing.expect(t, child_2.parent == root, "Child_2's parent should be root")
	testing.expect(t, root.last == child_2, "Root's first child should be child_1")
	testing.expect(t, child_2.prev == child_1, "Child_2's prev should be child_1")
	testing.expect(t, child_2.next == nil, "Child_2's next should be nil")
}
