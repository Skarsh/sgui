#version 330 core

layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color_start;
layout(location=2) in vec4 a_color_end;
layout(location=3) in vec2 a_gradient_dir;
layout(location=4) in vec2 a_quad_half_size;
layout(location=5) in vec2 a_quad_pos;
layout(location=6) in vec2 a_tex_coords;
layout(location=7) in int a_tex_slot;
layout(location=8) in float a_radius;

uniform mat4 transform;

out vec4 v_color_start;
out vec4 v_color_end;
out vec2 v_gradient_dir;
out vec2 v_tex_coords;
out vec2 v_quad_half_size;
out vec2 v_local_pos;
flat out int v_tex_slot;
out float v_radius;

void main() {
    gl_Position = transform * vec4(a_position, 1.0);
    v_color_start = a_color_start;
    v_color_end = a_color_end;
    v_gradient_dir = a_gradient_dir;
    v_quad_half_size = a_quad_half_size;

    // Calculate the local position of the vertex relative to the quad's center.
    // This will be interpolated for each fragment
    v_local_pos = a_position.xy - a_quad_pos;

    v_tex_coords = a_tex_coords;
    v_tex_slot = a_tex_slot;
    v_radius = a_radius;
}
