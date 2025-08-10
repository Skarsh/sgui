#version 330 core

in vec4 v_color;
in vec2 v_tex_coords;

out vec4 o_color;

uniform sampler2D u_texture;

void main() {
    // If tex_coords are negative, it's a solid shape, not text.
    if (v_tex_coords.x < 0.0) {
        o_color = v_color;
    } else {
        // Sample the font texture. The 'r' component has the alpha value.
        float alpha = texture(u_texture, v_tex_coords).r;
        o_color = vec4(v_color.rgb, v_color.a * alpha);
    }
}
