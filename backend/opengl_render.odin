package backend

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:reflect"
import "core:slice"

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


set_and_enable_vertex_attributes :: proc($T: typeid) {
	ti := runtime.type_info_base(type_info_of(T))
	info := ti.variant.(runtime.Type_Info_Struct)

	idx: u32 = 0
	size: i32 = 0
	normalized := false
	stride: i32 = size_of(T)
	offset: uintptr

	for name, i in info.names[:info.field_count] {

		field := reflect.struct_field_by_name(Vertex, name)
		type := field.type

		idx = u32(i)
		offset = field.offset

		#partial switch type_info in type.variant {
		case runtime.Type_Info_Integer:
			size = 1
			gl.VertexAttribIPointer(idx, size, gl.INT, stride, offset)
			gl.EnableVertexAttribArray(idx)
		case runtime.Type_Info_Float:
			size = 1
			gl.VertexAttribPointer(idx, size, gl.FLOAT, normalized, stride, offset)
			gl.EnableVertexAttribArray(idx)
		case runtime.Type_Info_Array:
			size = i32(type_info.count)
			#partial switch array_type_info in type_info.elem.variant {
			case runtime.Type_Info_Float:
				gl.VertexAttribPointer(idx, size, gl.FLOAT, normalized, stride, offset)
				gl.EnableVertexAttribArray(idx)
			case:
				panic(
					fmt.tprintf(
						"unsupported array type for setting vertex attribute: %v",
						type_info.elem.variant,
					),
				)
			}
		case:
			panic(fmt.tprintf("unsupported type for setting vertex attribute: %v", type.variant))
		}
	}
}

compare_draw_commands :: proc(cmd_1, cmd_2: ui.Draw_Command) -> bool {
	if cmd_1.z_index != cmd_2.z_index {
		return cmd_1.z_index < cmd_2.z_index
	}

	// Stable sort based on insertion order
	return cmd_1.cmd_idx < cmd_2.cmd_idx
}

Vertex :: struct {
	pos: base.Vec3,
}

// Explicit quad type for cleaner shader dispatch
Quad_Type :: enum i32 {
	Rect      = 0,
	Text      = 1,
	Image     = 2,
	Checkmark = 3,
}

Quad_Param :: struct #align (16) {
	// Rect fill
	color_start:         base.Vec4,
	color_end:           base.Vec4,
	gradient_dir:        base.Vec2,
	_padding_1:          base.Vec2,

	// Border fill
	border_color_start:  base.Vec4,
	border_color_end:    base.Vec4,
	border_gradient_dir: base.Vec2,
	_padding_2:          base.Vec2,
	clip_rect:           base.Vec4,

	// Others
	quad_pos:            base.Vec2,
	quad_size:           base.Vec2,
	uv_offset:           base.Vec2,
	uv_size:             base.Vec2,
	tex_slot:            i32,
	quad_type:           i32,
	stroke_thickness:    f32,
	_padding_3:          f32,
	// Mapping: x=top, y=right, z=bottom, w=left
	border:              base.Vec4,
	// Mapping: x=top-left, y=top-right, z=bottom-right, w=bottom-left
	border_radius:       base.Vec4,
}

Batch :: struct {
	vertices:      [dynamic]Vertex,
	indices:       [dynamic]u32,
	vertex_offset: i32,
	quad_idx:      i32,
}

// Helper struct for converting Fill to GPU-compatible color values
Fill_Colors :: struct {
	color_start:  base.Vec4,
	color_end:    base.Vec4,
	gradient_dir: base.Vec2,
}

// Converts a Fill to color values suitable for the GPU
fill_to_colors :: proc(fill: base.Fill) -> Fill_Colors {
	switch fill.kind {
	case .Solid:
		color := base.color_to_vec4(fill.color)
		return Fill_Colors{color, color, {0, 0}}
	case .Gradient:
		return Fill_Colors {
			base.color_to_vec4(fill.gradient.color_start),
			base.color_to_vec4(fill.gradient.color_end),
			fill.gradient.direction,
		}
	case .Not_Set, .None:
		return Fill_Colors{{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0}}
	}
	return {}
}

reset_batch :: proc(batch: ^Batch) {
	clear(&batch.vertices)
	clear(&batch.indices)
	batch.vertex_offset = 0
	batch.quad_idx = 0
}

OpenGL_Render_Data :: struct {
	window_size:   base.Vector2i32,
	vao:           u32,
	vbo:           u32,
	ebo:           u32,
	ssbo:          u32,
	ssbo_data:     []Quad_Param,
	shader:        Shader,
	font_atlas:    Font_Atlas,
	font_texture:  OpenGL_Texture,
	proj:          linalg.Matrix4f32,
	texture_store: Texture_Store,
	scissor_stack: [dynamic]base.Rect,
}

MAX_QUADS :: 10_000
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
	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	// TODO(Thomas): Hardcoding VSync here, should be coming from options struct eventually
	sdl.GL_SetSwapInterval(1)

	gl.load_up_to(4, 3, sdl.gl_set_proc_address)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	gl.Disable(gl.SCISSOR_TEST)

	shader, shader_ok := create_shader(
		Shader_Config{"shaders/main_vs.glsl", "shaders/main_fs.glsl"},
	)
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

	unit_vertices := [4]Vertex {
		{pos = {0.5, 0.5, 0}}, // Top Right
		{pos = {0.5, -0.5, 0}}, // Bottom Right
		{pos = {-0.5, -0.5, 0}}, // Bottom Left
		{pos = {-0.5, 0.5, 0}}, // Top Left
	}
	unit_indices := [6]u32{0, 1, 3, 1, 2, 3}

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(unit_vertices), &unit_vertices, gl.STATIC_DRAW)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(unit_indices), &unit_indices, gl.STATIC_DRAW)

	set_and_enable_vertex_attributes(Vertex)

	// SSBO
	ssbo_data := make([]Quad_Param, MAX_QUADS, allocator)

	ssbo: u32
	gl.GenBuffers(1, &ssbo)

	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, ssbo)
	gl.BufferData(
		gl.SHADER_STORAGE_BUFFER,
		size_of(Quad_Param) * MAX_QUADS,
		raw_data(ssbo_data),
		gl.DYNAMIC_DRAW,
	)
	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
	gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, ssbo)

	gl.BindVertexArray(0)

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
	data.window_size = base.Vector2i32{width, height}
	data.vao = vao
	data.vbo = vbo
	data.ebo = ebo
	data.ssbo = ssbo
	data.ssbo_data = ssbo_data
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

	data.scissor_stack = make([dynamic]base.Rect, allocator)

	render_data^ = data
	return true
}

deinit_opengl :: proc(render_data: ^OpenGL_Render_Data) {
	gl.DeleteVertexArrays(1, &render_data.vao)
	gl.DeleteBuffers(1, &render_data.vbo)
	gl.DeleteBuffers(1, &render_data.ebo)
	gl.DeleteBuffers(1, &render_data.ssbo)
	gl.DeleteTextures(1, &render_data.font_texture.id)
	gl.DeleteProgram(render_data.shader.id)
}

// TODO(Thomas): Just remove this?
opengl_init_resources :: proc(render_data: ^OpenGL_Render_Data) -> bool {
	return true
}

opengl_resize :: proc(render_data: ^OpenGL_Render_Data, width, height: i32) {
	gl.Viewport(0, 0, width, height)
	gl.Scissor(0, 0, width, height)
	render_data.proj = linalg.matrix_ortho3d_f32(0, f32(width), f32(height), 0, -1, 1)
	render_data.window_size.x = width
	render_data.window_size.y = height
}

opengl_render_begin :: proc(render_data: ^OpenGL_Render_Data) {
	gl.ClearColor(0.1, 0.1, 0.1, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

opengl_render_end :: proc(
	window: ^sdl.Window,
	render_data: ^OpenGL_Render_Data,
	command_queue: []ui.Draw_Command,
) {

	if len(command_queue) == 0 {
		return
	}

	slice.sort_by(command_queue[:], compare_draw_commands)

	clear(&render_data.scissor_stack)

	batch := Batch {
		make([dynamic]Vertex, 0, len(command_queue) * 4, context.temp_allocator),
		make([dynamic]u32, 0, len(command_queue) * 6, context.temp_allocator),
		0,
		0,
	}
	defer free_all(context.temp_allocator)

	shader_use_program(render_data.shader)

	// Set the viewport resolution
	resolution := base.Vec2{f32(render_data.window_size.x), f32(render_data.window_size.y)}
	shader_set_vec2(render_data.shader, "u_resolution", &resolution)

	// NOTE(Thomas): We're binding the font texture here by default
	// for now, even though we might not have a draw command that requires it.
	opengl_active_texture(.Texture_0)
	opengl_bind_texture(i32(render_data.font_texture.id))
	shader_set_int(render_data.shader, "u_font_texture", 0)

	// Reset the texture store each frame because the
	// ids can have changed between the frames.
	reset_texture_store(&render_data.texture_store)
	reset_batch(&batch)

	for command in command_queue {
		cmd := command.command
		#partial switch val in cmd {
		case ui.Command_Rect:
			border_radius := val.border_radius
			border := val.border
			border_vec := base.Vec4{border.top, border.right, border.bottom, border.left}

			fill_colors := fill_to_colors(val.fill)
			border_colors := fill_to_colors(val.border_fill)

			if batch.quad_idx >= MAX_QUADS {
				flush_render(render_data, batch)
				reset_batch(&batch)
			}

			rect := val.rect

			render_data.ssbo_data[batch.quad_idx] = Quad_Param {
				// Rect Fill
				color_start         = fill_colors.color_start,
				color_end           = fill_colors.color_end,
				gradient_dir        = fill_colors.gradient_dir,
				// Border Fill
				border_color_start  = border_colors.color_start,
				border_color_end    = border_colors.color_end,
				border_gradient_dir = border_colors.gradient_dir,
				// Clip Rect
				clip_rect           = {
					f32(command.clip_rect.x),
					f32(command.clip_rect.y),
					f32(command.clip_rect.w),
					f32(command.clip_rect.h),
				},
				// Others
				quad_pos            = {
					f32(rect.x) + f32(rect.w) / 2,
					f32(rect.y) + f32(rect.h) / 2,
				},
				quad_size           = {f32(rect.w), f32(rect.h)},
				uv_offset           = {-1, -1},
				uv_size             = {0, 0},
				tex_slot            = 0,
				quad_type           = i32(Quad_Type.Rect),
				border              = border_vec,
				border_radius       = border_radius,
			}
			batch.quad_idx += 1
		case ui.Command_Text:
			x := val.x
			y := val.y
			start_x := x
			start_y := y + render_data.font_atlas.metrics.ascent

			if val.fill.kind == .Gradient {
				panic("TODO: Implement gradient text")
			}
			fill_colors := fill_to_colors(val.fill)

			// Measure space width once for tab character handling
			space_glyph, space_found := get_glyph(&render_data.font_atlas, ' ')
			space_width: f32 = 0
			if space_found {
				space_q: stbtt.aligned_quad
				space_x := f32(0)
				space_y := f32(0)
				stbtt.GetPackedQuad(
					&render_data.font_atlas.packed_chars[0],
					render_data.font_atlas.atlas_width,
					render_data.font_atlas.atlas_height,
					space_glyph.pc_idx,
					&space_x,
					&space_y,
					&space_q,
					true,
				)
				space_width = space_x
			}

			for r in val.str {
				if r == '\n' {
					continue
				}

				// Handle tab character by advancing cursor without rendering
				if r == '\t' {
					start_x += base.calculate_tab_width(space_width)
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

				if batch.quad_idx >= MAX_QUADS {
					flush_render(render_data, batch)
					reset_batch(&batch)
				}

				// Set Quad_Param in ubo data
				width := (q.x1 - q.x0)
				height := (q.y1 - q.y0)
				render_data.ssbo_data[batch.quad_idx] = Quad_Param {
					color_start  = fill_colors.color_start,
					color_end    = fill_colors.color_end,
					gradient_dir = fill_colors.gradient_dir,
					clip_rect    = {
						f32(command.clip_rect.x),
						f32(command.clip_rect.y),
						f32(command.clip_rect.w),
						f32(command.clip_rect.h),
					},
					quad_pos     = {q.x0 + width / 2, q.y0 + height / 2},
					quad_size    = {width, height},
					uv_offset    = {q.s0, q.t0},
					uv_size      = {q.s1 - q.s0, q.t1 - q.t0},
					tex_slot     = 0,
					quad_type    = i32(Quad_Type.Text),
				}

				batch.quad_idx += 1
			}
		case ui.Command_Image:
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

			if batch.quad_idx >= MAX_QUADS {
				flush_render(render_data, batch)
				reset_batch(&batch)
			}

			x := val.x
			y := val.y
			w := val.w
			h := val.h

			render_data.ssbo_data[batch.quad_idx] = Quad_Param {
				color_start  = {1, 1, 1, 1},
				color_end    = {1, 1, 1, 1},
				gradient_dir = {0, 0},
				clip_rect    = {
					f32(command.clip_rect.x),
					f32(command.clip_rect.y),
					f32(command.clip_rect.w),
					f32(command.clip_rect.h),
				},
				quad_pos     = {x + w / 2, y + h / 2},
				quad_size    = {w, h},
				uv_offset    = {0, 0},
				uv_size      = {1, 1},
				tex_slot     = tex_slot,
				quad_type    = i32(Quad_Type.Image),
			}

			batch.quad_idx += 1
		case ui.Command_Shape:
			fill_colors := fill_to_colors(val.data.fill)

			if batch.quad_idx >= MAX_QUADS {
				flush_render(render_data, batch)
				reset_batch(&batch)
			}

			rect := val.rect
			thickness := val.data.thickness

			// Map ui.Shape_Kind to Quad_Type
			quad_type: Quad_Type
			switch val.data.kind {
			case .Checkmark:
				quad_type = .Checkmark
			}

			render_data.ssbo_data[batch.quad_idx] = Quad_Param {
				color_start      = fill_colors.color_start,
				color_end        = fill_colors.color_end,
				gradient_dir     = fill_colors.gradient_dir,
				clip_rect        = {
					f32(command.clip_rect.x),
					f32(command.clip_rect.y),
					f32(command.clip_rect.w),
					f32(command.clip_rect.h),
				},
				quad_pos         = {f32(rect.x) + f32(rect.w) / 2, f32(rect.y) + f32(rect.h) / 2},
				quad_size        = {f32(rect.w), f32(rect.h)},
				uv_offset        = {-1, -1},
				uv_size          = {0, 0},
				tex_slot         = 0,
				quad_type        = i32(quad_type),
				stroke_thickness = thickness,
			}

			batch.quad_idx += 1
		}

		// Flush if full
		if batch.quad_idx >= MAX_QUADS {
			flush_render(render_data, batch)
			reset_batch(&batch)
		}
	}

	flush_render(render_data, batch)
}

flush_render :: proc(render_data: ^OpenGL_Render_Data, batch: Batch) {
	if batch.quad_idx == 0 do return

	gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, render_data.ssbo)
	gl.BufferSubData(
		gl.SHADER_STORAGE_BUFFER,
		0,
		int(batch.quad_idx) * size_of(Quad_Param),
		raw_data(render_data.ssbo_data),
	)

	gl.BindVertexArray(render_data.vao)
	shader_use_program(render_data.shader)

	model := linalg.Matrix4f32(1.0)
	transform := render_data.proj * model
	err := shader_set_mat4(render_data.shader, "transform", &transform)
	if err != .None {
		log.error("Error setting shader uniform: ", err)
	}

	gl.DrawElementsInstanced(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil, batch.quad_idx)

	gl.BindVertexArray(0)
}
