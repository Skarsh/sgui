package backend

import "core:log"
import "core:math/linalg"
import gl "vendor:OpenGL"
import sdl "vendor:sdl2"

import base "../base"
import ui "../ui"

Vertex :: struct {
	pos:   base.Vec3,
	color: base.Vec4,
}


// odinfmt: disable
//vertices := []Vertex {
//    {{ 1.0,  1.0, 0}, {1.0, 0.0, 0.0, 1.0}},
//    {{ 1.0, -1.0, 0}, {0.0, 1.0, 0.0, 1.0}},
//    {{-1.0, -1.0, 0}, {0.0, 0.0, 1.0, 1.0}},
//    {{-1.0,  1.0, 0}, {1.0, 0.0, 1.0, 1.0}},
//}

vertices := []Vertex {
    {{ 0.5,  0.5, 0}, {1.0, 0.0, 0.0, 1.0}},
    {{ 0.5, -0.5, 0}, {0.0, 1.0, 0.0, 1.0}},
    {{-0.5, -0.5, 0}, {0.0, 0.0, 1.0, 1.0}},
    {{-0.5,  0.5, 0}, {1.0, 0.0, 1.0, 1.0}},
}

indices := []u32{
    0, 1, 3,
    1, 2, 3,
}
// odinfmt: enable

OpenGL_Render_Data :: struct {
	vao:    u32,
	vbo:    u32,
	ebo:    u32,
	shader: Shader,
}

// TODO(Thomas): Replace with our own window wrapper type, or at least
// figure out a way to not make this dependent on SDL.
init_opengl :: proc(render_data: ^Render_Data, window: ^sdl.Window) -> bool {
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

	render_data^ = OpenGL_Render_Data{vao, vbo, ebo, shader}
	return true
}

deinit_opengl :: proc(render_data: ^OpenGL_Render_Data) {
	gl.DeleteVertexArrays(1, &render_data.vao)
	gl.DeleteBuffers(1, &render_data.vbo)
	gl.DeleteBuffers(1, &render_data.ebo)
	gl.DeleteProgram(render_data.shader.id)
}

opengl_init_resources :: proc(render_data: ^OpenGL_Render_Data, paths: []string) -> bool {
	return true
}

opengl_render_begin :: proc(render_Data: ^OpenGL_Render_Data) {
	gl.ClearColor(0.5, 0.7, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

opengl_render_end :: proc(
	window: ^sdl.Window,
	render_data: OpenGL_Render_Data,
	command_queue: []ui.Command,
) {
	gl.BindVertexArray(render_data.vao)

	shader_use_program(render_data.shader)
	model := linalg.Matrix4f32(1.0)
	shader_set_mat4(render_data.shader, "proj", &model)
	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)
}
