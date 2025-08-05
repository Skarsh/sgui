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
    {{-0.5,  0.5, 0}, {1.0, 0.0, 0.0, 0.75}},
    {{-0.5, -0.5, 0}, {1.0, 1.0, 0.0, 0.75}},
    {{ 0.5, -0.5, 0}, {0.0, 1.0, 0.0, 0.75}},
    {{ 0.5,  0.5, 0}, {0.0, 0.0, 1.0, 0.75}},
}

indices := []u16{
    0, 1, 2, 
    2, 3, 0,
}
// odinfmt: enable

Render_Data :: struct {
	vao: u32,
	vbo: u32,
	ebo: u32,
}


// TODO(Thomas): Replace with our own window wrapper type
init_opengl :: proc(window: ^sdl.Window) {
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)

	program, program_ok := gl.load_shaders_file("shaders/main.vs", "shaders/main.fs")
	if !program_ok {
		log.error("Failed to create GLSL program")
		return
	}
	//defer gl.DeleteProgram(program)

	gl.UseProgram(program)
	uniforms := gl.get_uniforms_from_program(program)
	//defer delete(uniforms)

	vao: u32
	gl.GenVertexArrays(1, &vao)
	//defer gl.DeleteVertexArrays(1, &vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	//defer gl.DeleteBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	//defer gl.DeleteBuffers(1, &ebo)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices[0]),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, color))

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(indices[0]),
		raw_data(indices),
		gl.STATIC_DRAW,
	)
}

opengl_render_begin :: proc() {
	gl.ClearColor(0.5, 0.7, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

opengl_render_end :: proc(window: ^sdl.Window) {
	gl.DrawElements(gl.TRIANGLES, i32(len(indices)), gl.UNSIGNED_SHORT, nil)
	sdl.GL_SwapWindow(window)
}
