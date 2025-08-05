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


vertex_source := `#version 330 core
layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color;
out vec4 v_color;
uniform mat4 u_transform;
void main() {
    gl_Position = u_transform * vec4(a_position, 1.0);
    v_color = a_color;
}`


fragment_source := `#version 330 core
in vec4 v_color;
out vec4 o_color;
void main() {
    o_color = v_color;
}`


init_opengl :: proc(window: ^sdl.Window) {
	gl_context := sdl.GL_CreateContext(window)
	sdl.GL_MakeCurrent(window, gl_context)

	gl.load_up_to(3, 3, sdl.gl_set_proc_address)

	program, program_ok := gl.load_shaders_source(vertex_source, fragment_source)
	if !program_ok {
		log.error("Failed to create GLSL program")
		return
	}
	defer gl.DeleteProgram(program)

	gl.UseProgram(program)
	uniforms := gl.get_uniforms_from_program(program)
	defer delete(uniforms)

	vao: u32
	gl.GenVertexArrays(1, &vao)
	defer gl.DeleteVertexArrays(1, &vao)

	vbo, ebo: u32
	gl.GenBuffers(1, &vbo)
	defer gl.DeleteBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)
	defer gl.DeleteBuffers(1, &ebo)
}
