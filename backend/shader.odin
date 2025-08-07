package backend

import "core:log"
import "core:math/linalg"
import "core:os"
import "core:strings"

import gl "vendor:OpenGL"

Shader_Type :: enum {
	Vertex,
	Fragment,
}

Shader :: struct {
	id: u32,
}

Shader_Config :: struct {
	vertex_path:   string,
	fragment_path: string,
}

create_shader :: proc(config: Shader_Config) -> (Shader, bool) {

	shader_program := gl.CreateProgram()

	vertex_data, vertex_ok := os.read_entire_file(config.vertex_path, context.temp_allocator)
	defer free_all(context.temp_allocator)
	if !vertex_ok {
		log.error("Failed to read vertex shader file")
		return {}, false
	}

	vertex_source := transmute(string)vertex_data
	vertex_source_cstring := strings.clone_to_cstring(vertex_source, context.temp_allocator)

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_source_cstring, nil)
	gl.CompileShader(vertex_shader)
	check_shader_compile_status(Shader_Type.Vertex, vertex_shader)
	gl.AttachShader(shader_program, vertex_shader)

	fragment_data, fragment_ok := os.read_entire_file(config.fragment_path, context.temp_allocator)
	if !fragment_ok {
		log.error("Failed to read fragment shader file")
	}

	fragment_source := transmute(string)fragment_data
	fragment_source_cstring := strings.clone_to_cstring(fragment_source, context.temp_allocator)

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_source_cstring, nil)
	gl.CompileShader(fragment_shader)
	check_shader_compile_status(Shader_Type.Fragment, fragment_shader)
	gl.AttachShader(shader_program, fragment_shader)

	gl.LinkProgram(shader_program)

	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	check_program_link_status(shader_program)

	return Shader{id = shader_program}, true
}

shader_use_program :: proc(shader: Shader) {
	gl.UseProgram(shader.id)
}

shader_set_bool :: proc(shader: Shader, name: string, val: bool) {
	name_cstr, err := strings.clone_to_cstring(name, context.temp_allocator)
	defer free_all(context.temp_allocator)
	if err != nil {
		log.error("Failed to clone string to cstring, with error %v", err)
	}
	gl.Uniform1i(gl.GetUniformLocation(shader.id, name_cstr), i32(val))
}

shader_set_mat4 :: proc(shader: Shader, name: string, mat: ^linalg.Matrix4f32) {
	name_cstr, err := strings.clone_to_cstring(name, context.temp_allocator)
	defer free_all(context.temp_allocator)
	if err != nil {
		log.error("Failed to clone string to cstring, with error %v", err)
	}
	gl.UniformMatrix4fv(gl.GetUniformLocation(shader.id, name_cstr), 1, false, &mat[0][0])
}

@(private)
check_shader_compile_status :: proc(shader_type: Shader_Type, shader_id: u32) {
	INFO_LOG_LENGTH :: 512
	success: i32
	info_log := [INFO_LOG_LENGTH]u8{}
	gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(shader_id, INFO_LOG_LENGTH, nil, &info_log[0])

		shader_type_str: string
		switch shader_type {
		case .Vertex:
			shader_type_str = "VERTEX"
		case .Fragment:
			shader_type_str = "FRAGMENT"
		}
		log.errorf("%s, ERROR::SHADER::COMPILATION_FAILED\n%s", shader_type_str, info_log)
		panic("Failed to compile shader")
	}
}

@(private)
check_program_link_status :: proc(program: u32) {
	INFO_LOG_LENGTH :: 512
	success: i32
	info_log := [INFO_LOG_LENGTH]u8{}
	gl.GetProgramiv(program, gl.LINK_STATUS, &success)
	if success == 0 {
		gl.GetProgramInfoLog(program, INFO_LOG_LENGTH, nil, &info_log[0])
		log.errorf("ERROR::PROGRAM::LINKING_FAILED\n%s\n", info_log)
		panic("Failed to link shader")
	}

}
