#version 430 core

layout (location = 0) in vec3 a_position;

// Rect Fill
out vec4 v_color_start;
out vec4 v_color_end;
out vec2 v_gradient_dir;

// Border Fill
out vec4 v_border_color_start;
out vec4 v_border_color_end;
out vec2 v_border_gradient_dir;

// Clip Rect
out vec4 v_clip_rect;

out vec2 v_quad_half_size;
out vec2 v_local_pos;
out vec2 v_tex_coords;
flat out int v_tex_slot;
flat out int v_shape_kind;
out vec4 v_border;
out vec4 v_border_radius;

uniform mat4 transform;

// NOTE(Thomas): 16-byte alignment
struct QuadParams {
    // Rect fill
    vec4 color_start;
    vec4 color_end;
    vec2 gradient_dir;
    vec2 _padding_1;

    // Border fill
    vec4 border_color_start;
    vec4 border_color_end;
    vec2 border_gradient_dir;
    vec2 _padding_2;

    // Clip Rect
    vec4 clip_rect;

    vec2  quad_pos;
    vec2  quad_size;
    vec2  uv_offset;
    vec2  uv_size;
    int   tex_slot;
    int   shape_kind;
    vec2  _padding_3;
    vec4  border;
    vec4  border_radius;
};

layout (std430, binding = 0) readonly buffer QuadBlock {
    QuadParams instanceQuads[];
};

void main() {
    QuadParams quad = instanceQuads[gl_InstanceID];

    vec3 world_pos = vec3(
        (a_position.x * quad.quad_size.x) + quad.quad_pos.x,
        (a_position.y * quad.quad_size.y) + quad.quad_pos.y,
        a_position.z
    );

    gl_Position = transform * vec4(world_pos, 1.0);

    // UV Math:
    // a_position.xy is in range [-0.5, 0.5].
    // We map it to [0.0, 1.0] and then scale/offset by the UV data.
    vec2 uv_unit = a_position.xy + vec2(0.5);
    v_tex_coords = quad.uv_offset + (uv_unit * quad.uv_size);

    // SDF / Shape Math:
    // a_position is centered at (0,0) with range [-0.5, 0.5].
    // Multiplying by quad_size gives us the position in pixels relative to the center.
    // e.g. for width 100: -0.5 * 100 = -50 (Left edge) to +50 (Right edge).
    v_local_pos = a_position.xy * quad.quad_size;

    v_quad_half_size = quad.quad_size * 0.5;

    // Pass-throughs
    // Rect Fill
    v_color_start = quad.color_start;
    v_color_end = quad.color_end;
    v_gradient_dir = quad.gradient_dir;

    // Clip Rect
    v_clip_rect = quad.clip_rect;

    // Border Fill
    v_border_color_start = quad.border_color_start;
    v_border_color_end = quad.border_color_end;
    v_border_gradient_dir = quad.border_gradient_dir;

    v_tex_slot = quad.tex_slot;
    v_shape_kind = quad.shape_kind;
    v_border = quad.border;
    v_border_radius = quad.border_radius;
}
