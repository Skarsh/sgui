package backend

import "core:log"
import "core:strings"

import sdl "vendor:sdl2"
import sdl_img "vendor:sdl2/image"
import stbtt "vendor:stb/truetype"

import ui "../ui"

SDL_Texture_Asset :: struct {
	tex:   ^sdl.Texture,
	w:     i32,
	h:     i32,
	scale: f32,
	pivot: struct {
		x: f32,
		y: f32,
	},
}

SDL_Render_Data :: struct {
	renderer:      ^sdl.Renderer,
	textures:      [dynamic]SDL_Texture_Asset,
	scissor_stack: [dynamic]sdl.Rect,
	font_atlas:    Font_Atlas,
}

sdl_init_render :: proc(
	render_data: ^Render_Data,
	window: ^sdl.Window,
	stb_font_ctx: STB_Font_Context,
	font_size: f32,
	allocator := context.allocator,
) -> bool {
	renderer := sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED)
	if renderer == nil {
		log.error("Unable to create renderer: ", sdl.GetError())
		return false
	}

	font_atlas := Font_Atlas{}
	init_font_atlas(
		&font_atlas,
		stb_font_ctx.font_info,
		stb_font_ctx.font_data,
		"data/font.ttf",
		font_size,
		1024,
		1024,
		renderer,
		allocator,
	)

	data := SDL_Render_Data{}
	data.renderer = renderer
	data.textures = make([dynamic]SDL_Texture_Asset, allocator)
	data.scissor_stack = make([dynamic]sdl.Rect, allocator)
	data.font_atlas = font_atlas
	render_data^ = data

	return true
}

sdl_deinit_render :: proc(render_data: ^SDL_Render_Data) {
	deinit_font_atlas(&render_data.font_atlas)
	sdl.DestroyRenderer(render_data.renderer)
}

sdl_load_texture :: proc(render_data: ^SDL_Render_Data, full_path: string) -> bool {
	logo_surface, logo_ok := sdl_load_surface_from_image_file(full_path)
	if !logo_ok {
		return false
	}

	tex := sdl.CreateTextureFromSurface(render_data.renderer, logo_surface)
	if tex == nil {
		log.error("Failed to crate texture from surface")
		return false
	}

	logo := SDL_Texture_Asset {
		tex   = tex,
		w     = logo_surface.w,
		h     = logo_surface.h,
		scale = 1.0,
		pivot = {0.5, 0.5},
	}

	sdl.FreeSurface(logo_surface)

	append(&render_data.textures, logo)

	return true
}

sdl_init_resources :: proc(render_data: ^SDL_Render_Data, paths: []string) -> bool {
	for path in paths {
		sdl_load_texture(render_data, path)
	}

	return true
}

sdl_load_surface_from_image_file :: proc(image_path: string) -> (^sdl.Surface, bool) {
	path := strings.clone_to_cstring(image_path, context.temp_allocator)
	surface := sdl_img.Load(path)
	if surface == nil {
		log.errorf("Couldn't load %v", image_path)
		return nil, false
	}

	return surface, true
}

sdl_render_line :: proc(renderer: ^sdl.Renderer, x0, y0, x1, y1: f32, color: sdl.Color) {
	sdl.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)
	sdl.RenderDrawLine(renderer, i32(x0), i32(y0), i32(x1), i32(y1))
}

sdl_render_image :: proc(render_data: ^SDL_Render_Data, x, y, w, h: f32, data: rawptr) {
	tex_idx := cast(^int)data
	tex := render_data.textures[tex_idx^]
	r := sdl.Rect {
		x = i32(x),
		y = i32(y),
		w = i32(w),
		h = i32(h),
	}
	sdl.RenderCopy(render_data.renderer, tex.tex, nil, &r)
}

sdl_render_text :: proc(atlas: ^Font_Atlas, text: string, x, y: f32, r, g, b, a: u8) {
	start_x := x
	start_y := y + atlas.metrics.ascent

	sdl.SetTextureColorMod(atlas.texture, r, g, b)
	sdl.SetTextureAlphaMod(atlas.texture, a)

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

	// TODO(Thomas): Should this be popped off a stack instead??
	sdl.SetTextureColorMod(atlas.texture, 255, 255, 255)
	sdl.SetTextureAlphaMod(atlas.texture, 255)
}

sdl_render_draw_commands :: proc(render_data: ^SDL_Render_Data, command_queue: []ui.Command) {

	clear(&render_data.scissor_stack)
	sdl.RenderSetClipRect(render_data.renderer, nil)

	for command in command_queue {
		switch val in command {
		case ui.Command_Rect:
			// NOTE(Thomas): If it's completely transparent,
			// we don't have to draw.
			if val.color.a == 0 {
				continue
			}

			rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}
			sdl.SetRenderDrawColor(
				render_data.renderer,
				val.color.r,
				val.color.g,
				val.color.b,
				val.color.a,
			)
			sdl.RenderDrawRect(render_data.renderer, &rect)
			sdl.RenderFillRect(render_data.renderer, &rect)
		case ui.Command_Text:
			sdl_render_text(
				&render_data.font_atlas,
				val.str,
				val.x,
				val.y,
				val.color.r,
				val.color.g,
				val.color.b,
				val.color.a,
			)
		case ui.Command_Image:
			sdl_render_image(render_data, val.x, val.y, val.w, val.h, val.data)
		case ui.Command_Push_Scissor:
			new_scissor_rect := sdl.Rect{val.rect.x, val.rect.y, val.rect.w, val.rect.h}

			if len(render_data.scissor_stack) > 0 {
				parent_rect := render_data.scissor_stack[len(render_data.scissor_stack) - 1]
				_ = sdl.IntersectRect(&parent_rect, &new_scissor_rect, &new_scissor_rect)
			}

			append(&render_data.scissor_stack, new_scissor_rect)
			sdl.RenderSetClipRect(render_data.renderer, &new_scissor_rect)

		case ui.Command_Pop_Scissor:
			_ = pop(&render_data.scissor_stack)

			if len(render_data.scissor_stack) > 0 {
				previous_rect := render_data.scissor_stack[len(render_data.scissor_stack) - 1]
				sdl.RenderSetClipRect(render_data.renderer, &previous_rect)
			} else {
				sdl.RenderSetClipRect(render_data.renderer, nil)
			}
		}
	}

	sdl.RenderSetClipRect(render_data.renderer, nil)
}

sdl_render_begin :: proc(render_data: ^SDL_Render_Data) {
	bg_color := ui.default_color_style[.Window_BG]
	sdl.SetRenderDrawColor(render_data.renderer, bg_color.r, bg_color.g, bg_color.b, 255)
	sdl.RenderClear(render_data.renderer)
}

sdl_render_end :: proc(render_data: ^SDL_Render_Data, command_queue: []ui.Command) {
	sdl_render_draw_commands(render_data, command_queue)
	sdl.RenderPresent(render_data.renderer)
}
