#version 330 core

in vec4 v_color;
in vec2 v_quad_half_size;
in vec2 v_quad_pos;
in vec2 v_tex_coords;
flat in int v_tex_slot;
in float v_radius;

out vec4 o_color;

uniform sampler2D u_font_texture;

uniform sampler2D u_image_texture_1;
uniform sampler2D u_image_texture_2;
uniform sampler2D u_image_texture_3;
uniform sampler2D u_image_texture_4;
uniform sampler2D u_image_texture_5;

float sdfRect(vec2 pos, vec2 halfSize, float r) {
    vec2 q = abs(pos) - halfSize + vec2(r, r);
    return length(max(q, vec2(0))) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    // If tex_coords are negative, it's a solid shape, not text.
    if (v_tex_coords.x < 0.0) {
        o_color = v_color;
    } else {
        switch (v_tex_slot){
            case 0:
                // Sample the font texture. The 'r' component has the alpha value.
                float alpha = texture(u_font_texture, v_tex_coords).r;
                o_color = vec4(v_color.rgb, v_color.a * alpha);
                break;
            case 1:
                o_color = texture(u_image_texture_1, v_tex_coords);
                break;
            case 2:
                o_color = texture(u_image_texture_2, v_tex_coords);
                break;
            case 3:
                o_color = texture(u_image_texture_3, v_tex_coords);
                break;
            case 4:
                o_color = texture(u_image_texture_4, v_tex_coords);
                break;
            case 5:
                o_color = texture(u_image_texture_5, v_tex_coords);
                break;
        }
    }
}
