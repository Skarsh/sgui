package backend

import "core:log"

import gl "vendor:OpenGL"

OpenGL_Texture :: struct {
	id:              u32,
	width:           i32,
	height:          i32,
	internal_format: gl.GL_Enum,
	image_format:    gl.GL_Enum,
	wrap_s:          gl.GL_Enum,
	wrap_t:          gl.GL_Enum,
	filter_min:      gl.GL_Enum,
	filter_mag:      gl.GL_Enum,
}

// TODO(Thomas): Make wrap and filter configurable through parameters
opengl_gen_texture :: proc(
	width: i32,
	height: i32,
	internal_format: gl.GL_Enum,
	image_format: gl.GL_Enum,
	data: [^]u8,
) -> (
	OpenGL_Texture,
	bool,
) {
	texture_id: u32
	gl.GenTextures(1, &texture_id)

	gl.BindTexture(gl.TEXTURE_2D, texture_id)
	texture := OpenGL_Texture {
		id              = texture_id,
		width           = width,
		height          = height,
		internal_format = internal_format,
		image_format    = image_format,
		wrap_s          = gl.GL_Enum(gl.REPEAT),
		wrap_t          = gl.GL_Enum(gl.REPEAT),
		filter_min      = gl.GL_Enum(gl.LINEAR),
		filter_mag      = gl.GL_Enum(gl.LINEAR),
	}

	if data == nil {
		log.error("data pointer is nil")
		return {}, false
	}

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		i32(texture.internal_format),
		width,
		height,
		0,
		u32(texture.image_format),
		gl.UNSIGNED_BYTE,
		data,
	)

	// Set the texture wrapping parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(texture.wrap_s))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(texture.wrap_t))

	// Set the texture filtering parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(texture.filter_min))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(texture.filter_mag))

	gl.GenerateMipmap(gl.TEXTURE_2D)
	gl.BindTexture(gl.TEXTURE_2D, 0)

	return texture, true
}

bind_texture :: proc(texture: OpenGL_Texture) {
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
}
