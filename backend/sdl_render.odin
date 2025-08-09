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
	font_texture:  ^sdl.Texture,
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
		allocator,
	)

	data := SDL_Render_Data{}
	data.renderer = renderer
	data.textures = make([dynamic]SDL_Texture_Asset, allocator)
	data.scissor_stack = make([dynamic]sdl.Rect, allocator)
	data.font_atlas = font_atlas

	// TODO(Thomas): Ordering when things happen here is important, e.g 
	// creating this texture relies on the renderer and font atlast having been initalized
	// and set on the render data. Would be nice to maybe robustify this a bit?
	if !sdl_create_texture_from_bitmap(&data) {
		log.error("Failed to create texture from bitmap")
		return false
	}

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

sdl_create_texture_from_bitmap :: proc(render_data: ^SDL_Render_Data) -> bool {
	// Convert single-channel bitmap to RGBA for SDL
	rgba_bitmap := make(
		[]u8,
		render_data.font_atlas.atlas_width * render_data.font_atlas.atlas_height * 4,
		context.temp_allocator,
	)

	// Convert grayscale to RGBA with white color and alpha from grayscale value
	for i in 0 ..< render_data.font_atlas.atlas_width * render_data.font_atlas.atlas_height {
		gray_value := render_data.font_atlas.bitmap[i]
		rgba_bitmap[i * 4 + 0] = 255 // R
		rgba_bitmap[i * 4 + 1] = 255 // G
		rgba_bitmap[i * 4 + 2] = 255 // B
		rgba_bitmap[i * 4 + 3] = gray_value // A
	}

	// Create SDL surface from RGBA data
	surface := sdl.CreateRGBSurfaceFrom(
		rawptr(raw_data(rgba_bitmap)),
		render_data.font_atlas.atlas_width,
		render_data.font_atlas.atlas_height,
		32, // Bits per pixel
		render_data.font_atlas.atlas_width * 4, // Pitch
		0x000000FF,
		0x0000FF00,
		0x00FF0000,
		0xFF000000, // RGBA masks
	)

	if surface == nil {
		log.error("Failed to create SDL surface")
		return false
	}

	// Create texture from surface
	render_data.font_texture = sdl.CreateTextureFromSurface(render_data.renderer, surface)
	if render_data.font_texture == nil {
		log.error("Failed to create texture from surface")
		return false
	}

	// Set blend mode for proper alpha blending
	sdl.SetTextureBlendMode(render_data.font_texture, .BLEND)

	return true
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

sdl_render_text :: proc(render_data: ^SDL_Render_Data, text: string, x, y: f32, r, g, b, a: u8) {
	start_x := x
	start_y := y + render_data.font_atlas.metrics.ascent

	sdl.SetTextureColorMod(render_data.font_texture, r, g, b)
	sdl.SetTextureAlphaMod(render_data.font_texture, a)

	for r in text {
		// TODO(Thomas): What to do with \t and so on?
		if r == '\n' {
			continue
		}

		glyph, found := get_glyph(&render_data.font_atlas, r)
		if !found && r != ' ' {
			log.warn("Glyph not found for rune:", r)
		}

		q: stbtt.aligned_quad

		stbtt.GetPackedQuad(
			&render_data.font_atlas.packed_chars[0],
			render_data.font_atlas.atlas_width,
			render_data.font_atlas.atlas_height,
			glyph.pc_idx,
			&start_x,
			&start_y,
			&q,
			true,
		)

		src_rect := sdl.Rect {
			x = i32(q.s0 * f32(render_data.font_atlas.atlas_width)),
			y = i32(q.t0 * f32(render_data.font_atlas.atlas_height)),
			w = i32((q.s1 - q.s0) * f32(render_data.font_atlas.atlas_width)),
			h = i32((q.t1 - q.t0) * f32(render_data.font_atlas.atlas_height)),
		}

		dst_rect := sdl.Rect {
			x = i32(q.x0),
			y = i32(q.y0),
			w = i32(q.x1 - q.x0),
			h = i32(q.y1 - q.y0),
		}

		sdl.RenderCopy(render_data.renderer, render_data.font_texture, &src_rect, &dst_rect)
	}

	// TODO(Thomas): Should this be popped off a stack instead??
	sdl.SetTextureColorMod(render_data.font_texture, 255, 255, 255)
	sdl.SetTextureAlphaMod(render_data.font_texture, 255)
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
				render_data,
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
