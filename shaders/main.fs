#version 330 core

in vec4 v_color;
in vec2 v_tex_coords;
flat in int v_tex_id;

out vec4 o_color;

uniform sampler2D u_font_texture;
uniform sampler2D u_image_texture;

void main() {
    // If tex_coords are negative, it's a solid shape, not text.
    if (v_tex_coords.x < 0.0) {
        o_color = v_color;
    } else {
        // Sample the font texture. The 'r' component has the alpha value.
        if (v_tex_id == 0) {
            float alpha = texture(u_font_texture, v_tex_coords).r;
            o_color = vec4(v_color.rgb, v_color.a * alpha);
        } else {
            o_color = texture(u_image_texture, v_tex_coords);
        }
    }
}
