#version 330 core

in vec4 v_color_start;
in vec4 v_color_end;
in vec2 v_gradient_dir;
in vec2 v_quad_half_size;
in vec2 v_local_pos;
in vec2 v_tex_coords;
flat in int v_tex_slot;
in float v_radius;
in float v_border_thickness;

out vec4 o_color;

uniform sampler2D u_font_texture;

uniform sampler2D u_image_texture_1;
uniform sampler2D u_image_texture_2;
uniform sampler2D u_image_texture_3;
uniform sampler2D u_image_texture_4;
uniform sampler2D u_image_texture_5;

vec2 translate(vec2 pos, vec2 offset) {
    return (pos - offset);
}

// Signed Distance Function for a rounded rectangle.
// pos: The current fragment's position relative to the center.
// halfSize: Half the width and height of the rectangle.
// r: The corner radius.
// Returns a negative value inside the rectangle, positive outside, and 0 on the edge.
float sdfRect(vec2 pos, vec2 halfSize, float r) {
    vec2 d = abs(pos) - (halfSize - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

void main() {
    // If tex_coords are negative, it's a solid/gradient shape, not text or an image.
    if (v_tex_coords.x < 0.0) {
        vec4 base_color;

        // Check if the gradient direction is a zero vector (SENTINEL for solid color)
        if (length(v_gradient_dir) < 0.001) {
            base_color = v_color_start;
        } else {
            vec2 dir = normalize(v_gradient_dir);

            // Project the local position onto the gradient direction to find the interpolation factor 't'.
            float max_projection = dot(v_quad_half_size, abs(dir));
            float current_projection = dot(v_local_pos, dir);
            float t = (current_projection + max_projection) / (2.0 * max_projection);
            t = clamp(t, 0.0, 1.0);

            base_color = mix(v_color_start, v_color_end, t);
        }
        // TODO(Thomas): Hardcoded border color
        vec4 border_color = vec4(0.0, 0.0, 0.0, base_color.a);
        float d_outer = sdfRect(v_local_pos, v_quad_half_size, v_radius);
        vec2 inner_half_size = v_quad_half_size - v_border_thickness;
        float inner_radius = max(0.0, v_radius - v_border_thickness);
        float d_inner = sdfRect(v_local_pos, inner_half_size, inner_radius);
        float smoothing = fwidth(d_outer);
        float alpha_shape = 1.0 - smoothstep(-smoothing, smoothing, d_outer);
        float alpha_fill = 1.0 - smoothstep(-smoothing, smoothing, d_inner);

        vec4 mixed_color = mix(border_color, base_color, alpha_fill);
        o_color = vec4(mixed_color.rgb, mixed_color.a * alpha_shape);

    } else { // This part is for textures (text, images) and remains unchanged.
        switch (v_tex_slot){
            case 0:
                // Sample the font texture. The 'r' component has the alpha value.
                float alpha = texture(u_font_texture, v_tex_coords).r;
                o_color = vec4(v_color_start.rgb, v_color_start.a * alpha);
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
