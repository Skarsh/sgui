package ui

import "core:testing"

Key_Test_Element :: struct {
	name:  string,
	id:    string,
	scope: string,
}

@(private)
build_key_test_element :: proc(ctx: ^Context, element: Key_Test_Element) {
	if element.scope != "" {
		push_id(ctx, element.scope)
	}

	container(ctx, name = element.name, id = element.id)

	if element.scope != "" {
		pop_id(ctx)
	}
}

@(private)
check_distinct_elements :: proc(
	t: ^testing.T,
	first, second: Key_Test_Element,
	loc := #caller_location,
) {
	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	begin(ctx)
	build_key_test_element(ctx, first)
	build_key_test_element(ctx, second)
	end(ctx)

	children := ctx.root_element.children
	if !testing.expectf(
		t,
		len(children) == 2,
		"expected two elements, got %d",
		len(children),
		loc = loc,
	) {
		return
	}

	testing.expectf(
		t,
		children[0].key != children[1].key,
		"expected elements %q and %q to have distinct identities",
		first.name,
		second.name,
		loc = loc,
	)
}

@(test)
test_explicit_ids_distinguish_elements_at_same_callsite :: proc(t: ^testing.T) {
	check_distinct_elements(t, {name = "First", id = "first"}, {name = "Second", id = "second"})
}

@(test)
test_push_id_scopes_explicit_ids :: proc(t: ^testing.T) {
	check_distinct_elements(
		t,
		{name = "First", id = "element", scope = "first"},
		{name = "Second", id = "element", scope = "second"},
	)
}

@(test)
test_push_id_scopes_implicit_ids :: proc(t: ^testing.T) {
	check_distinct_elements(
		t,
		{name = "First", scope = "first"},
		{name = "Second", scope = "second"},
	)
}

@(private)
build_element_at_first_callsite :: proc(ctx: ^Context) {
	container(ctx, name = "status", id = "status")
}

@(private)
build_element_at_second_callsite :: proc(ctx: ^Context) {
	container(ctx, name = "status", id = "status")
}

@(test)
test_explicit_id_survives_callsite_change :: proc(t: ^testing.T) {
	test_env := setup_test_environment(DEFAULT_TESTING_WINDOW_SIZE)
	defer cleanup_test_environment(test_env)
	ctx := &test_env.ctx

	begin(ctx)
	build_element_at_first_callsite(ctx)
	end(ctx)
	first_element := ctx.root_element.children[0]

	begin(ctx)
	build_element_at_second_callsite(ctx)
	end(ctx)
	second_element := ctx.root_element.children[0]

	testing.expectf(
		t,
		first_element == second_element,
		"expected an explicit ID to preserve the cached element across callsites",
	)
}
