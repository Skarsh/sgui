package backend

import log "core:log"
import gl "vendor:OpenGL"
import sdl "vendor:sdl2"

Vec3 :: [3]f32
Vec4 :: [4]f32

Vertex :: struct {
	pos:   Vec3,
	color: Vec4,
}

// odinfmt: disable
vertices := []Vertex {
    {{ 1.0,  1.0, 0}, {1.0, 0.0, 0.0, 1.0}},
    {{ 1.0, -1.0, 0}, {0.0, 1.0, 0.0, 1.0}},
    {{-1.0, -1.0, 0}, {0.0, 0.0, 1.0, 1.0}},
    {{-1.0,  1.0, 0}, {1.0, 0.0, 1.0, 1.0}},
}

indices := []u32{
    0, 1, 3,
    1, 2, 3,
}
// odinfmt: enable

OpenGL_Render_Data :: struct {
	vao:     u32,
	vbo:     u32,
	ebo:     u32,
	program: u32,
}

// TODO(Thomas): Replace with our own window wrapper type, or at least
// figure out a way to not make this dependent on SDL.
init_opengl :: proc(render_data: ^Render_Data, window: ^sdl.Window) -> bool {
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)

	program, program_ok := gl.load_shaders_file("shaders/main.vs", "shaders/main.fs")
	if !program_ok {
		log.error("Failed to create GLSL program")
		return false
	}

	vao: u32
	gl.GenVertexArrays(1, &vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices[0]),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(indices[0]),
		raw_data(indices),
		gl.STATIC_DRAW,
	)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))
	gl.EnableVertexAttribArray(1)

	gl.BindVertexArray(0)

	render_data^ = OpenGL_Render_Data{vao, vbo, ebo, program}
	return true
}

deinit_opengl :: proc(render_data: ^OpenGL_Render_Data) {
	gl.DeleteVertexArrays(1, &render_data.vao)
	gl.DeleteBuffers(1, &render_data.vbo)
	gl.DeleteBuffers(1, &render_data.ebo)
	gl.DeleteProgram(render_data.program)
}

opengl_init_resources :: proc(render_data: ^OpenGL_Render_Data, paths: []string) -> bool {
	return true
}

opengl_render_begin :: proc(render_Data: ^OpenGL_Render_Data) {
	gl.ClearColor(0.5, 0.7, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

opengl_render_end :: proc(window: ^sdl.Window, render_data: OpenGL_Render_Data) {
	gl.BindVertexArray(render_data.vao)

	gl.UseProgram(render_data.program)
	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)
}
