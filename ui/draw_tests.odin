package ui

import "core:testing"

@(test)
test_draw_command_buffer_uses_full_capacity :: proc(t: ^testing.T) {
	command_buffer: [1]Draw_Command
	ctx: Context

	init_draw_state(&ctx.draw_state, command_buffer[:])
	push_draw_command(&ctx.draw_state, Command_Rect{}, 0)

	commands := draw_commands(&ctx)

	testing.expect_value(t, ctx.draw_state.command_count, 1)
	testing.expect_value(t, len(commands), 1)
}

@(test)
test_draw_command_buffer_is_reused_after_reset :: proc(t: ^testing.T) {
	command_buffer: [2]Draw_Command
	ctx: Context

	init_draw_state(&ctx.draw_state, command_buffer[:])

	push_draw_command(&ctx.draw_state, Command_Rect{}, 1)
	push_draw_command(&ctx.draw_state, Command_Rect{}, 2)
	testing.expect_value(t, len(draw_commands(&ctx)), 2)

	reset_draw_state(&ctx.draw_state, {640, 480})
	testing.expect_value(t, len(draw_commands(&ctx)), 0)

	push_draw_command(&ctx.draw_state, Command_Rect{}, 3)

	commands := draw_commands(&ctx)
	testing.expect_value(t, len(commands), 1)
	testing.expect_value(t, commands[0].z_index, 3)
}
