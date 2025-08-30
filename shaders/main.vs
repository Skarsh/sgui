#version 330 core

layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color;
layout(location=2) in vec2 a_tex_coords;
layout(location=3) in int a_tex_slot;

uniform mat4 transform;

out vec4 v_color;
out vec2 v_tex_coords;
flat out int v_tex_slot;

void main() {
    gl_Position = transform * vec4(a_position, 1.0);
    v_color = a_color;
    v_tex_coords = a_tex_coords;
    v_tex_slot = a_tex_slot;
}
