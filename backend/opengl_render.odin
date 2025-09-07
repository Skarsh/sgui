package backend

import "core:c"
import "core:log"
import "core:math/linalg"
import gl "vendor:OpenGL"
import sdl "vendor:sdl2"
import stbtt "vendor:stb/truetype"

import base "../base"
import ui "../ui"

Texture_Store :: struct {
	idx_to_slot_map: map[i32]i32,
	start_slot:      i32,
	slot:            i32,
	max_slots:       i32,
}

reset_texture_store :: proc(store: ^Texture_Store) {
	store.slot = store.start_slot
	clear(&store.idx_to_slot_map)
}

Vertex :: struct {
	pos:            base.Vec3,
	color:          base.Vec4,
	quad_half_size: base.Vec2,
	quad_pos:       base.Vec2,
	tex:            base.Vec2,
	tex_slot:       i32,
	radius:         f32,
}

OpenGL_Render_Data :: struct {
	vao:           u32,
	vbo:           u32,
	ebo:           u32,
	shader:        Shader,
	font_atlas:    Font_Atlas,
	font_texture:  OpenGL_Texture,
	proj:          linalg.Matrix4f32,
	texture_store: Texture_Store,
}

MAX_QUADS :: 10000
MAX_VERTICES :: MAX_QUADS * 4
MAX_INDICES :: MAX_QUADS * 6

// TODO(Thomas): Replace with our own window wrapper type, or at least
// figure out a way to not make this dependent on SDL.
init_opengl :: proc(
	render_data: ^Render_Data,
	window: ^sdl.Window,
	width, height: i32,
	stb_font_ctx: STB_Font_Context,
	font_size: f32,
	allocator := context.allocator,
) -> bool {
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GLprofile.CORE))
	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)

	shader, shader_ok := create_shader(Shader_Config{"shaders/main.vs", "shaders/main.fs"})
	if !shader_ok {
		log.error("Failed to create shader")
		return false
	}

	vao: u32
	gl.GenVertexArrays(1, &vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, MAX_VERTICES * size_of(Vertex), nil, gl.DYNAMIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, MAX_INDICES * size_of(u32), nil, gl.DYNAMIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(
		2,
		2,
		gl.FLOAT,
		false,
		size_of(Vertex),
		offset_of(Vertex, quad_half_size),
	)
	gl.EnableVertexAttribArray(2)


	gl.VertexAttribPointer(3, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, quad_pos))
	gl.EnableVertexAttribArray(3)

	gl.VertexAttribPointer(4, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, tex))
	gl.EnableVertexAttribArray(4)

	gl.VertexAttribIPointer(5, 1, gl.INT, size_of(Vertex), offset_of(Vertex, tex_slot))
	gl.EnableVertexAttribArray(5)

	gl.VertexAttribPointer(6, 1, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, radius))
	gl.EnableVertexAttribArray(6)

	gl.BindVertexArray(0)

	// TODO(Thomas): Dimensions should come from window size, and it
	// should be updated when the window resizes.
	// NOTE(Thomas): Flipped y-axis for top-left coords
	ortho := linalg.matrix_ortho3d_f32(0, f32(width), f32(height), 0, -1, 1)

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

	data := OpenGL_Render_Data{}
	data.vao = vao
	data.vbo = vbo
	data.ebo = ebo
	data.shader = shader
	data.proj = ortho
	data.font_atlas = font_atlas

	// NOTE(Thomas): The font bitmap has only one channel, so we use
	// only the RED channel for the inernal and image format.
	font_texture, font_texture_ok := opengl_gen_texture(
		font_atlas.atlas_width,
		font_atlas.atlas_height,
		.RED,
		.RED,
		raw_data(font_atlas.bitmap),
	)

	if !font_texture_ok {
		log.error("Failed to generate font texture")
		return false
	}
	data.font_texture = font_texture

	MAX_TEXTURE_SLOTS :: 16
	//NOTE(Thomas): The start slot is 1 since the 0th slot is taken by font texture
	texture_store := Texture_Store{make(map[i32]i32, allocator), 1, 1, MAX_TEXTURE_SLOTS}
	data.texture_store = texture_store

	render_data^ = data
	return true
}

deinit_opengl :: proc(render_data: ^OpenGL_Render_Data) {
	gl.DeleteVertexArrays(1, &render_data.vao)
	gl.DeleteBuffers(1, &render_data.vbo)
	gl.DeleteBuffers(1, &render_data.ebo)
	gl.DeleteTextures(1, &render_data.font_texture.id)
	gl.DeleteProgram(render_data.shader.id)
}

opengl_init_resources :: proc(render_data: ^OpenGL_Render_Data, paths: []string) -> bool {
	return true
}

opengl_resize :: proc(render_data: ^OpenGL_Render_Data, width, height: i32) {
	gl.Viewport(0, 0, width, height)
	render_data.proj = linalg.matrix_ortho3d_f32(0, f32(width), f32(height), 0, -1, 1)
}

opengl_render_begin :: proc(render_data: ^OpenGL_Render_Data) {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

opengl_render_end :: proc(
	window: ^sdl.Window,
	render_data: ^OpenGL_Render_Data,
	command_queue: []ui.Command,
) {
	if len(command_queue) == 0 {
		return
	}

	// TODO(Thomas): Should come from an arena or something instead.
	vertices := make([dynamic]Vertex, 0, len(command_queue) * 4)
	indices := make([dynamic]u32, 0, len(command_queue) * 6)
	vertex_offset: u32 = 0

	shader_use_program(render_data.shader)

	// NOTE(Thomas): We're binding the font texture here by default
	// for now, even though we might not have a draw command that requires it.
	opengl_active_texture(.Texture_0)
	opengl_bind_texture(i32(render_data.font_texture.id))
	shader_set_int(render_data.shader, "u_font_texture", 0)

	// Reset the texture store each frame because the
	// ids can have changed between the frames.
	reset_texture_store(&render_data.texture_store)

	for command in command_queue {
		#partial switch val in command {
		case ui.Command_Rect:
			rect := val.rect
			x := f32(rect.x)
			y := f32(rect.y)
			w := f32(rect.w)
			h := f32(rect.h)

			radius := val.radius

			half_w := w / 2
			half_h := h / 2

			center_x := x + half_w
			center_y := y + half_h

			color := val.color
			r := f32(color.r) / 255
			g := f32(color.g) / 255
			b := f32(color.b) / 255
			a := f32(color.a) / 255

			// Bottom-right
			append(
				&vertices,
				Vertex {
					pos = {x + w, y + h, 0},
					color = {r, g, b, a},
					quad_half_size = {half_w, half_h},
					quad_pos = {center_x, center_y},
					tex = {-1, -1},
					radius = radius,
				},
			)

			// Top-right
			append(
				&vertices,
				Vertex {
					pos = {x + w, y, 0},
					color = {r, g, b, a},
					quad_half_size = {half_w, half_h},
					quad_pos = {center_x, center_y},
					tex = {-1, -1},
					radius = radius,
				},
			)

			// Top-left
			append(
				&vertices,
				Vertex {
					pos = {x, y, 0},
					color = {r, g, b, a},
					quad_half_size = {half_w, half_h},
					quad_pos = {center_x, center_y},
					tex = {-1, -1},
					radius = radius,
				},
			)

			// Bottom-left
			append(
				&vertices,
				Vertex {
					pos = {x, y + h, 0},
					color = {r, g, b, a},
					quad_half_size = {half_w, half_h},
					quad_pos = {center_x, center_y},
					tex = {-1, -1},
					radius = radius,
				},
			)

			rect_indices := [6]u32 {
				vertex_offset + 0,
				vertex_offset + 1,
				vertex_offset + 2,
				vertex_offset + 2,
				vertex_offset + 3,
				vertex_offset + 0,
			}
			append(&indices, ..rect_indices[:])

			vertex_offset += 4
		case ui.Command_Text:
			x := val.x
			y := val.y
			start_x := x
			start_y := y + render_data.font_atlas.metrics.ascent
			color := val.color

			red := f32(color.r) / 255
			green := f32(color.g) / 255
			blue := f32(color.b) / 255
			alpha := f32(color.a) / 255

			for r in val.str {
				if r == '\n' {
					continue
				}

				glyph, found := get_glyph(&render_data.font_atlas, r)
				if !found && r != ' ' {
					log.error("Glyph not found for rune: ", r)
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

				// Bottom right
				append(
					&vertices,
					Vertex {
						pos = {q.x1, q.y1, 0},
						color = {red, green, blue, alpha},
						tex = {q.s1, q.t1},
						tex_slot = 0,
					},
				)

				// Top right
				append(
					&vertices,
					Vertex {
						pos = {q.x1, q.y0, 0},
						color = {red, green, blue, alpha},
						tex = {q.s1, q.t0},
						tex_slot = 0,
					},
				)

				// Top left
				append(
					&vertices,
					Vertex {
						pos = {q.x0, q.y0, 0},
						color = {red, green, blue, alpha},
						tex = {q.s0, q.t0},
						tex_slot = 0,
					},
				)

				// Bottom left
				append(
					&vertices,
					Vertex {
						pos = {q.x0, q.y1, 0},
						color = {red, green, blue, alpha},
						tex = {q.s0, q.t1},
						tex_slot = 0,
					},
				)

				rect_indices := [6]u32 {
					vertex_offset + 0,
					vertex_offset + 1,
					vertex_offset + 2,
					vertex_offset + 2,
					vertex_offset + 3,
					vertex_offset + 0,
				}
				append(&indices, ..rect_indices[:])

				vertex_offset += 4
			}
		case ui.Command_Image:
			x := val.x
			y := val.y
			w := val.w
			h := val.h

			data := val.data
			tex_id := (cast(^i32)data)^

			// TODO(Thomas): This works but obviously has issues.
			// Move this stuff into its own procedure. When all the slots
			// have been reached and there's a new texture id that needs a new slot
			// we have to do a render call, reset and continue.
			tex_slot, exists := render_data.texture_store.idx_to_slot_map[tex_id]
			if !exists {
				tex_slot = render_data.texture_store.slot
				render_data.texture_store.idx_to_slot_map[tex_id] = tex_slot

				switch tex_slot {
				case 1:
					opengl_active_texture(.Texture_1)
					opengl_bind_texture(tex_id)
					shader_set_int(render_data.shader, "u_image_texture_1", 1)
				case 2:
					opengl_active_texture(.Texture_2)
					opengl_bind_texture(tex_id)
					shader_set_int(render_data.shader, "u_image_texture_2", 2)
				case 3:
					opengl_active_texture(.Texture_3)
					opengl_bind_texture(tex_id)
					shader_set_int(render_data.shader, "u_image_texture_3", 3)
				case 4:
					opengl_active_texture(.Texture_4)
					opengl_bind_texture(tex_id)
					shader_set_int(render_data.shader, "u_image_texture_4", 4)
				case 5:
					opengl_active_texture(.Texture_5)
					opengl_bind_texture(tex_id)
					shader_set_int(render_data.shader, "u_image_texture_5", 5)
				}

				render_data.texture_store.slot += 1
			}

			// Bottom right
			append(
				&vertices,
				Vertex {
					pos = {x + w, y + h, 0},
					color = {1, 1, 1, 1},
					tex = {1, 1},
					tex_slot = tex_slot,
				},
			)

			// Top right
			append(
				&vertices,
				Vertex {
					pos = {x + w, y, 0},
					color = {1, 1, 1, 1},
					tex = {1, 0},
					tex_slot = tex_slot,
				},
			)

			// Top left
			append(
				&vertices,
				Vertex{pos = {x, y, 0}, color = {1, 1, 1, 1}, tex = {0, 0}, tex_slot = tex_slot},
			)

			// Bottom left
			append(
				&vertices,
				Vertex {
					pos = {x, y + h, 0},
					color = {1, 1, 1, 1},
					tex = {0, 1},
					tex_slot = tex_slot,
				},
			)

			rect_indices := [6]u32 {
				vertex_offset + 0,
				vertex_offset + 1,
				vertex_offset + 2,
				vertex_offset + 2,
				vertex_offset + 3,
				vertex_offset + 0,
			}
			append(&indices, ..rect_indices[:])

			vertex_offset += 4
		}
	}

	gl.BindVertexArray(render_data.vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, render_data.vbo)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(vertices) * size_of(Vertex), raw_data(vertices))

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, render_data.ebo)
	gl.BufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, len(indices) * size_of(u32), raw_data(indices))

	shader_use_program(render_data.shader)
	model := linalg.Matrix4f32(1.0)
	transform := render_data.proj * model
	err := shader_set_mat4(render_data.shader, "transform", &transform)
	if err != .None {
		log.error("Error setting shader uniform: ", err)
	}

	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)

	// TODO(Thomas): Free an arena or something instead
	delete(vertices)
	delete(indices)
}
