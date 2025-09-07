#version 330 core

layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color;
layout(location=2) in vec2 a_quad_half_size;
layout(location=3) in vec2 a_quad_pos;
layout(location=4) in vec2 a_tex_coords;
layout(location=5) in int a_tex_slot;
layout(location=6) in float a_radius;

uniform mat4 transform;

out vec4 v_color;
out vec2 v_tex_coords;
out vec2 v_quad_half_size;
out vec2 v_quad_pos;
flat out int v_tex_slot;
out float v_radius;

void main() {
    gl_Position = transform * vec4(a_position, 1.0);
    v_color = a_color;
    v_quad_half_size = a_quad_half_size;
    v_quad_pos = a_quad_pos * a_quad_half_size;
    v_tex_coords = a_tex_coords;
    v_tex_slot = a_tex_slot;
    v_radius = a_radius;
}
