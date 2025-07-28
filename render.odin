package main

import "core:log"
import "core:strings"
import "ui"
import sdl "vendor:sdl2"
import sdl_img "vendor:sdl2/image"
import stbtt "vendor:stb/truetype"

Texture_Asset :: struct {
	tex:   ^sdl.Texture,
	w:     i32,
	h:     i32,
	scale: f32,
	pivot: struct {
		x: f32,
		y: f32,
	},
}

Render_Context :: struct {
	renderer:      ^sdl.Renderer,
	textures:      [dynamic]Texture_Asset,
	scissor_stack: [dynamic]sdl.Rect,
}

deinit_render_ctx :: proc(ctx: ^Render_Context) {
	sdl.DestroyRenderer(ctx.renderer)
}

init_resources :: proc(ctx: ^Render_Context) -> bool {
	logo_surface, logo_ok := load_surface_from_image_file(
		"./data/textures/skarsh_logo_192x192.png",
	)
	if !logo_ok {
		return false
	}

	tex := sdl.CreateTextureFromSurface(ctx.renderer, logo_surface)
	if tex == nil {
		log.error("Failed to crate texture from surface")
		return false
	}

	logo := Texture_Asset {
		tex   = tex,
		w     = logo_surface.w,
		h     = logo_surface.h,
		scale = 1.0,
		pivot = {0.5, 0.5},
	}

	sdl.FreeSurface(logo_surface)

	append(&ctx.textures, logo)

	return true
}

load_surface_from_image_file :: proc(image_path: string) -> (^sdl.Surface, bool) {
	path := strings.clone_to_cstring(image_path, context.temp_allocator)
	surface := sdl_img.Load(path)
	if surface == nil {
		log.errorf("Couldn't load %v", image_path)
		return nil, false
	}

	return surface, true
}

render_line :: proc(renderer: ^sdl.Renderer, x0, y0, x1, y1: f32, color: sdl.Color) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderDrawLine(renderer, i32(x0), i32(y0), i32(x1), i32(y1))
}

render_image :: proc(ctx: ^Render_Context, x, y, w, h: f32) {
	tex := ctx.textures[0]
	r := sdl.Rect {
		x = i32(x),
		y = i32(y),
		w = i32(w),
		h = i32(h),
	}
	sdl.RenderCopy(ctx.renderer, tex.tex, nil, &r)
}

render_text :: proc(atlas: ^Font_Atlas, text: string, x, y: f32) {
	start_x := x
	start_y := y + atlas.metrics.ascent

	for r in text {
		// TODO(Thomas): What to do with \t and so on?
		if r == '\n' {
			continue
		}

		glyph, found := get_glyph(atlas, r)
		if !found && r != ' ' {
			log.warn("Glyph not found for rune:", r)
		}

		q: stbtt.aligned_quad

		stbtt.GetPackedQuad(
			&atlas.packed_chars[0],
			atlas.atlas_width,
			atlas.atlas_height,
			glyph.pc_idx,
			&start_x,
			&start_y,
			&q,
			true,
		)

		src_rect := sdl.Rect {
			x = i32(q.s0 * f32(atlas.atlas_width)),
			y = i32(q.t0 * f32(atlas.atlas_height)),
			w = i32((q.s1 - q.s0) * f32(atlas.atlas_width)),
			h = i32((q.t1 - q.t0) * f32(atlas.atlas_height)),
		}

		dst_rect := sdl.Rect {
			x = i32(q.x0),
			y = i32(q.y0),
			w = i32(q.x1 - q.x0),
			h = i32(q.y1 - q.y0),
		}

		sdl.RenderCopy(atlas.renderer, atlas.texture, &src_rect, &dst_rect)
	}
}

render_draw_commands :: proc(app_state: ^App_State) {

	render_ctx := &app_state.render_ctx
	clear(&render_ctx.scissor_stack)
	sdl.RenderSetClipRect(render_ctx.renderer, nil)

	commands := [ui.COMMAND_STACK_SIZE]ui.Command{}

	idx := 0
	for command, ok := ui.pop(&app_state.ctx.command_stack);
	    ok;
	    command, ok = ui.pop(&app_state.ctx.command_stack) {
		commands[idx] = command
		idx += 1
	}

	#reverse for command in commands {
		switch val in command {
		case ui.Command_Rect:
			// NOTE(Thomas): If it's completely transparent,
			// we don't have to draw.
			if val.color.a == 0 {
				continue
			}

			rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}
			sdl.SetRenderDrawColor(
				render_ctx.renderer,
				val.color.r,
				val.color.g,
				val.color.b,
				val.color.a,
			)
			sdl.RenderDrawRect(render_ctx.renderer, &rect)
			sdl.RenderFillRect(render_ctx.renderer, &rect)
		case ui.Command_Text:
			render_text(&app_state.font_atlas, val.str, val.x, val.y)
		case ui.Command_Image:
			render_image(&app_state.render_ctx, val.x, val.y, val.w, val.h)
		case ui.Command_Push_Scissor:
			new_scissor_rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}

			if len(render_ctx.scissor_stack) > 0 {
				parent_rect := render_ctx.scissor_stack[len(render_ctx.scissor_stack) - 1]
				_ = sdl.IntersectRect(&parent_rect, &new_scissor_rect, &new_scissor_rect)
			}

			append(&render_ctx.scissor_stack, new_scissor_rect)
			sdl.RenderSetClipRect(render_ctx.renderer, &new_scissor_rect)

		case ui.Command_Pop_Scissor:
			_ = pop(&render_ctx.scissor_stack)

			if len(render_ctx.scissor_stack) > 0 {
				previous_rect := render_ctx.scissor_stack[len(render_ctx.scissor_stack) - 1]
				sdl.RenderSetClipRect(render_ctx.renderer, &previous_rect)
			} else {
				sdl.RenderSetClipRect(render_ctx.renderer, nil)
			}
		}
	}

	sdl.RenderSetClipRect(render_ctx.renderer, nil)
}
