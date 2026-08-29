package backend

import "core:log"
import "core:mem"
import "core:os"

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

create_shader :: proc(config: Shader_Config, scratch_allocator: mem.Allocator) -> (Shader, bool) {

	program := gl.CreateProgram()
	vertex_shader: u32
	fragment_shader: u32
	success := false

	// NOTE(Thomas): Cleans up after exiting the scope
	defer {
		if !success {
			if fragment_shader != 0 {
				gl.DeleteShader(fragment_shader)
			}
			if vertex_shader != 0 {
				gl.DeleteShader(vertex_shader)
			}
			if program != 0 {
				gl.DeleteProgram(program)
			}
		}
	}

	vertex_data, vertex_err := os.read_entire_file_from_path(config.vertex_path, scratch_allocator)
	if vertex_err != nil {
		log.error("Failed to read vertex shader file with error: ", vertex_err)
		return {}, false
	}

	vertex_source := cstring(raw_data(vertex_data))
	vertex_source_len := i32(len(vertex_data))

	vertex_shader = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, &vertex_source, &vertex_source_len)
	gl.CompileShader(vertex_shader)
	if !check_shader_compile_status(Shader_Type.Vertex, vertex_shader) {
		return {}, false
	}
	gl.AttachShader(program, vertex_shader)

	fragment_data, fragment_err := os.read_entire_file_from_path(
		config.fragment_path,
		scratch_allocator,
	)
	if fragment_err != nil {
		log.error("Failed to read fragment shader file with error: ", fragment_err)
		return {}, false
	}

	fragment_source := cstring(raw_data(fragment_data))
	fragment_source_len := i32(len(fragment_data))

	fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, &fragment_source, &fragment_source_len)
	gl.CompileShader(fragment_shader)
	if !check_shader_compile_status(Shader_Type.Fragment, fragment_shader) {
		return {}, false
	}

	gl.AttachShader(program, fragment_shader)

	gl.LinkProgram(program)
	if !check_program_link_status(program) {
		return {}, false
	}

	gl.DeleteShader(vertex_shader)
	vertex_shader = 0

	gl.DeleteShader(fragment_shader)
	fragment_shader = 0

	success = true

	return Shader{id = program}, success
}

shader_use_program :: proc(shader: Shader) {
	gl.UseProgram(shader.id)
}

shader_set_int :: proc(shader: Shader, name: cstring, val: i32) {
	gl.Uniform1i(gl.GetUniformLocation(shader.id, name), val)
}

shader_set_vec2 :: proc(shader: Shader, name: cstring, val: ^[2]f32) {
	gl.Uniform2fv(gl.GetUniformLocation(shader.id, name), 1, &val[0])
}

shader_set_mat4 :: proc(shader: Shader, name: cstring, mat: ^matrix[4, 4]f32) {
	gl.UniformMatrix4fv(gl.GetUniformLocation(shader.id, name), 1, false, &mat[0][0])
}

@(private)
check_shader_compile_status :: proc(shader_type: Shader_Type, shader_id: u32) -> bool {
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
		return false
	}
	return true
}

@(private)
check_program_link_status :: proc(program: u32) -> bool {
	INFO_LOG_LENGTH :: 512
	success: i32
	info_log := [INFO_LOG_LENGTH]u8{}
	gl.GetProgramiv(program, gl.LINK_STATUS, &success)
	if success == 0 {
		gl.GetProgramInfoLog(program, INFO_LOG_LENGTH, nil, &info_log[0])
		log.errorf("ERROR::PROGRAM::LINKING_FAILED\n%s\n", info_log)
		return false
	}
	return true
}
