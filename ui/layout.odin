package ui

import "core:log"
import "core:mem"
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

	// Key and frame info
	key:                   UI_Key,
	last_frame_touched:    u64,

	// Per-frame builder info
	flags:                 Widget_Flag_Set,
	string:                string,
	semantic_size:         [Axis2_Size]Size,
	discovered:            bool,

	// recomputed every frame
	// Computed position relative to the parent position
	computed_rel_position: [Axis2_Size]f32,
	// Computed size in pixels
	computed_size:         [Axis2_Size]f32,
	// NOTE(Thomas): Not entirely sure about this rect
	// and how it should be represented.
	rect:                  Rect,
	color_style:           Color_Style,

	// Persistent animation data
	hot:                   f32,
	active:                f32,
}

widget_make :: proc(
	ctx: ^Context,
	string: string,
	flags: Widget_Flag_Set = {},
	semantic_size: [Axis2_Size]Size = [Axis2_Size]Size{},
) -> (
	^Widget,
	bool,
) {

	key := ui_key_hash(string)

	// Try to get the widget from the cache first
	widget, found := ctx.widget_cache[key]

	if !found {
		err: mem.Allocator_Error
		widget, err = new(Widget, ctx.persistent_allocator)
		if err != nil {
			log.error("failed to allocated widget")
			return nil, false
		}

		// Update widget state, important to set parent
		// before using widget.parent to set tree links
		widget.parent = ctx.current_parent
		widget.flags = flags
		widget.string = string
		widget.semantic_size = semantic_size
		widget.last_frame_touched = ctx.frame_index
		ok: bool
		widget.color_style, ok = peek(&ctx.style_stack)
		if !ok {
			widget.color_style = default_color_style
		}

		// We only need to deal with the non root case, since that's
		// already dealt with by default from setting the widget state above.
		if widget.parent != nil {
			// We know we're first (which also means last)
			if widget.parent.first == nil {
				widget.parent.first = widget
				widget.parent.last = widget
			} else {
				// We have to be somewhere in the sibling chain
				// We can easily extend to that chain by using the last pointer
				widget.parent.last.next = widget
				widget.prev = widget.parent.last
				widget.parent.last = widget
			}
		}

		ctx.widget_cache[key] = widget
	}

	// Discovered needs to be reset for every frame
	// due to it being used in the layout algorithm
	widget.discovered = false

	return widget, true
}

// Push a new widget to become the parent
push_parent :: proc(ctx: ^Context, widget: ^Widget) -> (^Widget, bool) {
	prev_parent := ctx.current_parent
	ok := push(&ctx.parent_stack, prev_parent)
	if !ok {
		log.error("Failed to push parent onto parent stack / list")
		return nil, false
	}

	ctx.current_parent = widget

	return prev_parent, true
}

pop_parent :: proc(ctx: ^Context) -> (^Widget, bool) {

	popped_parent := ctx.current_parent

	parent_from_stack, ok := pop(&ctx.parent_stack)
	if !ok {
		return nil, false
	}

	ctx.current_parent = parent_from_stack

	return popped_parent, true
}

Comm :: struct {
	widget:         ^Widget,
	mouse:          Vector2i32,
	drag_delta:     Vector2i32,
	clicked:        bool,
	double_clicked: bool,
	held:           bool,
	released:       bool,
	dragging:       bool,
	hovering:       bool,
}

// TODO(Thomas): This is very incomplete
comm_from_widget :: proc(ctx: ^Context, widget: ^Widget) -> Comm {
	comm: Comm
	comm.widget = widget

	if point_in_rect(ctx.input.mouse_pos, widget.rect) {
		comm.hovering = true
		comm.mouse = ctx.input.mouse_pos

		// TODO(Thomas): The hot animation accumulation here should
		// be time based instead and its should follow exponential / easing functions
		// instead of a linear accumulation
		if widget.hot < 1.0 {
			widget.hot += 0.05
		} else {
			widget.hot = 1.0
		}

		// TODO(Thomas): Not exactly sure what to do here in the pressed vs held, set both like it is now?
		if is_mouse_pressed(ctx^, .Left) {
			comm.clicked = true
		}

		if is_mouse_down(ctx^, .Left) {
			comm.held = true
		}
	} else {
		widget.hot = 0.0
	}

	return comm
}

render_widget :: proc(ctx: ^Context, widget: ^Widget) {
	widget.discovered = true

	color := widget.color_style[.Base]

	if .Hot_Animation in widget.flags {
		hot_color := widget.color_style[.Hot]
		t := widget.hot
		color = lerp_color(color, hot_color, t)
	}

	draw_rect(ctx, widget.rect, color)

	if widget.first != nil && !widget.first.discovered {
		render_widget(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		render_widget(ctx, widget.next)
	}
}

// TODO(Thomas): Return error?
button :: proc(ctx: ^Context, id_key: string) -> Comm {
	flags: Widget_Flag_Set = {
		.Clickable,
		.Draw_Border,
		.Draw_Text,
		.Draw_Background,
		.Hot_Animation,
		.Active_Animation,
	}

	semantic_size: [Axis2_Size]Size = {
		Size{kind = .Pixels, value = 64, strictness = 1.0},
		Size{kind = .Pixels, value = 48, strictness = 1.0},
	}

	widget, _ := widget_make(ctx, id_key, flags, semantic_size)

	comm := comm_from_widget(ctx, widget)

	return comm
}

// TODO(Thomas): Return error?
//NOTE(Thomas): This should converted to a more general panel or row
// widget later. This is primarily for testing right now.
button_panel :: proc(ctx: ^Context, id_key: string) -> Comm {
	flags: Widget_Flag_Set = {}


	semantic_size := [Axis2_Size]Size {
		Size{kind = .Percent_Of_Parent, value = 100, strictness = 1.0},
		Size{kind = .Children_Sum, value = 100, strictness = 1.0},
	}

	widget, _ := widget_make(ctx, id_key, flags, semantic_size)
	comm := comm_from_widget(ctx, widget)

	return comm
}

begin :: proc(ctx: ^Context) {
	ctx.ui_state.hot_item = ui_key_null()
	ctx.command_stack.idx = -1
}

calculate_standalone_sizes :: proc(ctx: ^Context, widget: ^Widget) {
	if widget == nil {
		return
	}

	// Process this widget
	for axis in Axis2 {
		if widget.semantic_size[axis].kind == .Pixels {
			widget.computed_size[axis] = widget.semantic_size[axis].value
		}
	}


	widget.discovered = true

	if widget.first != nil && !widget.first.discovered {
		calculate_standalone_sizes(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		calculate_standalone_sizes(ctx, widget.next)
	}
}

calculate_upwards_dependent :: proc(ctx: ^Context, widget: ^Widget) {
	if widget == nil {
		return
	}

	for axis in Axis2 {
		if widget.semantic_size[axis].kind == .Percent_Of_Parent {
			widget.computed_size[axis] = widget.parent.computed_size[axis]
		}
	}

	widget.discovered = true

	if widget.first != nil && !widget.first.discovered {
		calculate_upwards_dependent(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		calculate_upwards_dependent(ctx, widget.next)
	}
}

calculate_downwards_dependent :: proc(ctx: ^Context, widget: ^Widget) {
	if widget == nil {
		return
	}

	if widget.first != nil && !widget.first.discovered {
		calculate_downwards_dependent(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		calculate_downwards_dependent(ctx, widget.next)
	}

	widget.discovered = true
}

calculate_positions :: proc(ctx: ^Context, widget: ^Widget) {
	if widget == nil {
		return
	}

	// TODO(Thomas): This is just hardcoded for axis now.
	// This obviously has to change.
	for axis in Axis2 {
		if widget.parent != nil {
			if widget.prev == nil {
				widget.computed_rel_position = widget.parent.computed_rel_position.x
			} else {
				widget.computed_rel_position.x =
					widget.prev.computed_rel_position.x + widget.prev.computed_size.x
			}
		}
	}

	widget.rect = Rect {
		i32(widget.computed_rel_position[Axis2.X]),
		i32(widget.computed_rel_position[Axis2.Y]),
		i32(widget.computed_size[Axis2.X]),
		i32(widget.computed_size[Axis2.Y]),
	}

	widget.discovered = true

	if widget.first != nil && !widget.first.discovered {
		calculate_positions(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		calculate_positions(ctx, widget.next)
	}
}

perform_layout :: proc(ctx: ^Context) {
	// 1. (Any order is acceptable) Calculate "standalone" sizes.These are size that
	// do not depend on other widgets and can be calculated purely with the
	// information that comes from the single widget that is having its size
	// calculated. (Size_Kind.Pixels, Size_Kind.Text_Content)
	calculate_standalone_sizes(ctx, ctx.root_widget)

	// 2. (Pre-order) Calculate "upwards-dependent" sizes. These are sizes that
	// strictly depend on an ancestor's size, other than ancestors that have
	// "downwards-dependent" sizes on the given axis. (Size_Kind.Percent_Of_Parent)
	clear_discovered(ctx.root_widget)
	calculate_upwards_dependent(ctx, ctx.root_widget)

	// 3. (Post-order) Calculate "downwards-dependent" sizes. These are size that
	// depend on sizes of descendants. (Size_Kind.Children_Sum)
	clear_discovered(ctx.root_widget)
	calculate_downwards_dependent(ctx, ctx.root_widget)

	// 4. (Pre-order) Solve violations. For each level in the hierarchy, this will verify
	// that the children do not extend past the boundaries of a given parent
	// (unless explicitly allowed to do so; for example, in the case of a parent that
	// is scrollable on the given axis), to the best of the algorithm's ability.
	// If there is a violation, it will take a proportion of each child widget's size
	// (on the given axis), proportional to both the size of the vioaltion, and (1 - strictness),
	// where strictness is that specified in the semantic size on the child widget for the given axis.

	// 5. (Pre-order) Finally, given the calculated sizes of each widget, compute the
	// relative positions of each widget (by laying out on an axis which can be specified on any parent node).
	// This stage can also compute the final screen-coordinates rectangle.
	clear_discovered(ctx.root_widget)
	calculate_positions(ctx, ctx.root_widget)
}

render_all_widgets :: proc(ctx: ^Context) {
	clear_discovered(ctx.root_widget)
	render_widget(ctx, ctx.root_widget)
}

end :: proc(ctx: ^Context) {
	ctx.frame_index += 1

	perform_layout(ctx)

	render_all_widgets(ctx)

	// TODO(Thomas): Prune unused widgets here?

	clear_input(ctx)
	free_all(ctx.frame_allocator)
}

@(test)
test_button_panel_widget_hierarchy :: proc(t: ^testing.T) {
	ctx := Context{}
	init(&ctx, context.temp_allocator, context.temp_allocator)
	defer free_all(context.temp_allocator)

	root, ok := widget_make(&ctx, "root")
	testing.expect(t, ok, "Root widget should be created successfully")
	testing.expect(t, root != nil, "Root widget should be created successfully")

	// Push root as parent
	prev, root_push_ok := push_parent(&ctx, root)
	testing.expect(t, root_push_ok, "Should successfully push root as parent")
	testing.expect(t, prev == nil, "Previous parent should be nil")
	testing.expect(t, ctx.current_parent == root, "Container's parent should be root")

	// Create child button panel
	button_panel, button_panel_ok := widget_make(&ctx, "button_panel")
	testing.expect(t, button_panel_ok)

	testing.expect(t, root.first == button_panel)
	testing.expect(t, root.last == button_panel)
	testing.expect(t, root.next == nil)
	testing.expect(t, root.prev == nil)

	testing.expect(t, button_panel.parent == root)
	testing.expect(t, button_panel.first == nil)
	testing.expect(t, button_panel.last == nil)
	testing.expect(t, button_panel.next == nil)
	testing.expect(t, button_panel.prev == nil)

	button_panel_prev_parent, button_panel_push_ok := push_parent(&ctx, button_panel)
	testing.expect(t, button_panel_push_ok, "Should successfully push button_panel as parent")
	testing.expect(t, button_panel_prev_parent == root, "Previous parent should be root")
	testing.expect(
		t,
		ctx.current_parent == button_panel,
		"Ctx current_parent should be button_panel",
	)

	// Button 1
	button_1, button_1_ok := widget_make(&ctx, "button_1")
	testing.expect(t, button_1_ok)

	testing.expect(t, button_panel.first == button_1)
	testing.expect(t, button_panel.last == button_1)
	testing.expect(t, button_panel.next == nil)
	testing.expect(t, button_1.parent == button_panel)
	testing.expect(t, button_1.first == nil)
	testing.expect(t, button_1.last == nil)
	testing.expect(t, button_1.next == nil)
	testing.expect(t, button_1.prev == nil)

	// Button 2
	button_2, button_2_ok := widget_make(&ctx, "button_2")
	testing.expect(t, button_2_ok)

	testing.expect(t, button_panel.first == button_1)
	testing.expect(t, button_panel.last == button_2)
	testing.expect(t, button_panel.next == nil)
	testing.expect(t, button_1.next == button_2)
	testing.expect(t, button_2.parent == button_panel)
	testing.expect(t, button_2.first == nil)
	testing.expect(t, button_2.last == nil)
	testing.expect(t, button_2.next == nil)
	testing.expect(t, button_2.prev == button_1)

	// Button 3
	button_3, button_3_ok := widget_make(&ctx, "button_3")
	testing.expect(t, button_3_ok)

	testing.expect(t, button_panel.first == button_1)
	testing.expect(t, button_panel.last == button_3)
	testing.expect(t, button_panel.next == nil)
	testing.expect(t, button_1.next == button_2)
	testing.expect(t, button_1.parent == button_panel)
	testing.expect(t, button_2.next == button_3)
	testing.expect(t, button_2.parent == button_panel)
	testing.expect(t, button_3.parent == button_panel)
	testing.expect(t, button_3.first == nil)
	testing.expect(t, button_3.last == nil)
	testing.expect(t, button_3.next == nil)
	testing.expect(t, button_3.prev == button_2)

	// Pop button_panel
	button_panel_popped, button_panel_popped_ok := pop_parent(&ctx)
	testing.expect(t, button_panel_popped_ok)
	testing.expect(t, button_panel_popped == button_panel)
	testing.expect(t, ctx.current_parent == root)

	// Now we make a second button panel
	// Create child button panel
	button_panel_2, button_panel_2_ok := widget_make(&ctx, "button_panel_2")
	testing.expect(t, button_panel_2_ok)

	button_panel_2_prev_parent, button_panel_2_push_ok := push_parent(&ctx, button_panel_2)

	testing.expect(t, root.first == button_panel)
	testing.expect(t, root.last == button_panel_2)
	testing.expect(t, root.next == nil)
	testing.expect(t, root.prev == nil)

	testing.expect(t, button_panel.parent == root)
	testing.expect(t, button_panel.first == button_1)
	testing.expect(t, button_panel.last == button_3)
	testing.expect(t, button_panel.next == button_panel_2)
	testing.expect(t, button_panel.prev == nil)

	testing.expect(t, button_panel_2.parent == root)
	testing.expect(t, button_panel_2.next == nil)
	testing.expect(t, button_panel_2.prev == button_panel)

	// Button 4
	button_4, button_4_ok := widget_make(&ctx, "button_4")
	testing.expect(t, button_1_ok)

	testing.expect(t, button_panel_2.first == button_4)
	testing.expect(t, button_panel_2.last == button_4)
	testing.expect(t, button_panel_2.next == nil)
	testing.expect(t, button_4.parent == button_panel_2)
	testing.expect(t, button_4.first == nil)
	testing.expect(t, button_4.last == nil)
	testing.expect(t, button_4.next == nil)
	testing.expect(t, button_4.prev == nil)

	// Button 5
	button_5, button_5_ok := widget_make(&ctx, "button_5")
	testing.expect(t, button_5_ok)

	testing.expect(t, button_panel_2.first == button_4)
	testing.expect(t, button_panel_2.last == button_5)
	testing.expect(t, button_panel_2.next == nil)
	testing.expect(t, button_4.next == button_5)
	testing.expect(t, button_5.parent == button_panel_2)
	testing.expect(t, button_5.first == nil)
	testing.expect(t, button_5.last == nil)
	testing.expect(t, button_5.next == nil)
	testing.expect(t, button_5.prev == button_4)

	// Button 6
	button_6, button_6_ok := widget_make(&ctx, "button_6")
	testing.expect(t, button_6_ok)

	testing.expect(t, button_panel_2.first == button_4)
	testing.expect(t, button_panel_2.last == button_6)
	testing.expect(t, button_panel_2.next == nil)
	testing.expect(t, button_4.next == button_5)
	testing.expect(t, button_4.parent == button_panel_2)
	testing.expect(t, button_5.next == button_6)
	testing.expect(t, button_5.parent == button_panel_2)
	testing.expect(t, button_6.parent == button_panel_2)
	testing.expect(t, button_6.first == nil)
	testing.expect(t, button_6.last == nil)
	testing.expect(t, button_6.next == nil)
	testing.expect(t, button_6.prev == button_5)

	// Pop button_panel_2
	button_panel_2_popped, button_panel_2_popped_ok := pop_parent(&ctx)
	testing.expect(t, button_panel_2_popped_ok)
	testing.expect(t, button_panel_2_popped == button_panel_2)

	// Pop root
	root_panel_popped, root_panel_popped_ok := pop_parent(&ctx)
	testing.expect(t, root_panel_popped_ok)
	testing.expect(t, root_panel_popped == root)
}

clear_discovered :: proc(widget: ^Widget) {
	if widget == nil {
		return
	}

	widget.discovered = false
	clear_discovered(widget.first)
	clear_discovered(widget.next)
}

traverse_widget_hierarchy :: proc(ctx: ^Context, widget: ^Widget) {
	widget.discovered = true

	log.info(widget.string)

	if widget.first != nil && !widget.first.discovered {
		traverse_widget_hierarchy(ctx, widget.first)
	}

	if widget.next != nil && !widget.next.discovered {
		traverse_widget_hierarchy(ctx, widget.next)
	}
}

@(test)
test_widget_hierarchy_traversal :: proc(t: ^testing.T) {

	ctx := Context{}
	init(&ctx, context.temp_allocator, context.temp_allocator)

	// A simple three button "panel" hierarchy
	root, ok := widget_make(&ctx, "root")
	testing.expect(t, ok, "Root widget should be created successfully")
	testing.expect(t, root != nil, "Root widget should be created successfully")

	// Push root as parent
	push_parent(&ctx, root)

	panel_1, panel_1_ok := widget_make(&ctx, "panel_1")
	testing.expect(t, panel_1_ok)

	push_parent(&ctx, panel_1)

	button_1_comm := button(&ctx, "button_1")
	button_2_comm := button(&ctx, "button_2")
	button_3_comm := button(&ctx, "button_3")

	pop_parent(&ctx)

	panel_2, panel_2_ok := widget_make(&ctx, "panel_2")
	testing.expect(t, panel_2_ok)

	push_parent(&ctx, panel_2)

	button_4_comm := button(&ctx, "button_4")
	button_5_comm := button(&ctx, "button_5")
	button_6_comm := button(&ctx, "button_6")

	pop_parent(&ctx)


	traverse_widget_hierarchy(&ctx, root)
	testing.expect(t, root.discovered == true)
	testing.expect(t, button_1_comm.widget.discovered == true)
	testing.expect(t, button_2_comm.widget.discovered == true)
	testing.expect(t, button_3_comm.widget.discovered == true)
	testing.expect(t, button_4_comm.widget.discovered == true)
	testing.expect(t, button_5_comm.widget.discovered == true)
	testing.expect(t, button_6_comm.widget.discovered == true)

	// Pop root as parent
	root_popped, root_popped_ok := pop_parent(&ctx)
	testing.expect(t, root_popped_ok)
	testing.expect(t, root_popped == root)

	clear_discovered(root)
	testing.expect(t, root.discovered == false)
	testing.expect(t, button_1_comm.widget.discovered == false)
	testing.expect(t, button_2_comm.widget.discovered == false)
	testing.expect(t, button_3_comm.widget.discovered == false)
	testing.expect(t, button_4_comm.widget.discovered == false)
	testing.expect(t, button_5_comm.widget.discovered == false)
	testing.expect(t, button_6_comm.widget.discovered == false)
}
