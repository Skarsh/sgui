#version 330 core

// Fill
in vec4 v_color_start;
in vec4 v_color_end;
in vec2 v_gradient_dir;

// Border Fill
in vec4 v_border_color_start;
in vec4 v_border_color_end;
in vec2 v_border_gradient_dir;

in vec2 v_quad_half_size;
in vec2 v_local_pos;
in vec2 v_tex_coords;
flat in int v_tex_slot;
in float v_radius;
in float v_border_thickness;

out vec4 o_color;

uniform vec2 u_resolution;

uniform sampler2D u_font_texture;

uniform sampler2D u_image_texture_1;
uniform sampler2D u_image_texture_2;
uniform sampler2D u_image_texture_3;
uniform sampler2D u_image_texture_4;
uniform sampler2D u_image_texture_5;

// Calculates alpha based on signed distance for smooth anti-aliasing
// d: The signed distance from the edge
// Returns alpha (1.0 for inside and 0.0 for outside, smooth transition on the edge).
float sdfAlpha(float d) {
    float width = fwidth(d);
    return smoothstep(width, -width, d);
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

vec4 calcGradientColor(vec4 color_start, vec4 color_end, vec2 dir, vec2 half_size, vec2 pos) {
    vec2 u = normalize(dir);

    float proj = dot(pos, u);

    // NOTE(Thomas): We use abs(u) here to ensure that max_proj will be positive, since
    // this is essentially the max length, and negative length doesn't make sense.
    float max_proj = dot(half_size, abs(u));

    float t = (proj + max_proj) / (2.0 * max_proj);

    return mix(color_start, color_end, clamp(t, 0.0, 1.0));
}

void main() {
    // If tex_coords are negative, it's a solid/gradient shape, not text or an image.
    if (v_tex_coords.x < 0.0) {

        float d_border = sdfRect(v_local_pos, v_quad_half_size, v_radius);
        float d_inner = sdfRect(v_local_pos, v_quad_half_size - v_border_thickness, max(0.0, v_radius - v_border_thickness));

        float alpha_border = sdfAlpha(d_border);
        float alpha_inner = sdfAlpha(d_inner);

        vec4 border_color = calcGradientColor(
            v_border_color_start,
            v_border_color_end,
            v_border_gradient_dir,
            v_quad_half_size,
            v_local_pos
        );

        vec4 inner_color = calcGradientColor(
            v_color_start,
            v_color_end,
            v_gradient_dir,
            v_quad_half_size - v_border_thickness,
            v_local_pos
        );

        vec4 final_material = mix(border_color, inner_color, alpha_inner);

        o_color = vec4(final_material.rgb, final_material.a * alpha_border);

    } else {
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
