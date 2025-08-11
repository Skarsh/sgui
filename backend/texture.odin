package backend

import "core:log"

import gl "vendor:OpenGL"

Texture_Constant :: enum int {
	Texture_0  = gl.TEXTURE0,
	Texture_1  = gl.TEXTURE1,
	Texture_2  = gl.TEXTURE2,
	Texture_3  = gl.TEXTURE3,
	Texture_4  = gl.TEXTURE4,
	Texture_5  = gl.TEXTURE5,
	Texture_6  = gl.TEXTURE6,
	Texture_7  = gl.TEXTURE7,
	Texture_8  = gl.TEXTURE8,
	Texture_9  = gl.TEXTURE9,
	Texture_10 = gl.TEXTURE10,
	Texture_11 = gl.TEXTURE11,
	Texture_12 = gl.TEXTURE12,
	Texture_13 = gl.TEXTURE13,
	Texture_14 = gl.TEXTURE14,
	Texture_15 = gl.TEXTURE15,
	Texture_16 = gl.TEXTURE16,
	Texture_17 = gl.TEXTURE17,
	Texture_18 = gl.TEXTURE18,
	Texture_19 = gl.TEXTURE19,
	Texture_20 = gl.TEXTURE20,
	Texture_21 = gl.TEXTURE21,
	Texture_22 = gl.TEXTURE22,
	Texture_23 = gl.TEXTURE23,
	Texture_24 = gl.TEXTURE24,
	Texture_25 = gl.TEXTURE25,
	Texture_26 = gl.TEXTURE26,
	Texture_27 = gl.TEXTURE27,
	Texture_28 = gl.TEXTURE28,
	Texture_29 = gl.TEXTURE29,
	Texture_30 = gl.TEXTURE30,
	Texture_31 = gl.TEXTURE31,
}

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

opengl_bind_texture :: proc(texture: OpenGL_Texture) {
	gl.BindTexture(gl.TEXTURE_2D, texture.id)
}

opengl_unbind_texture :: proc(texture: OpenGL_Texture) {
	gl.BindTexture(gl.TEXTURE_2D, 0)
}

opengl_active_texture :: proc(texture_constant: Texture_Constant) {
	gl.ActiveTexture(u32(texture_constant))
}
