#version 330 core

in vec4 v_color;
in vec2 v_tex_coords;

out vec4 o_color;

uniform sampler2D u_texture;

void main() {
    float alpha = texture(u_texture, v_tex_coords).r;
    o_color = vec4(v_color.rgb, v_color.a * alpha);
}
