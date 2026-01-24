#version 430 core

// Rect fiill
in vec4 v_color_start;
in vec4 v_color_end;
in vec2 v_gradient_dir;

// Border Fill
in vec4 v_border_color_start;
in vec4 v_border_color_end;
in vec2 v_border_gradient_dir;

// Clip Rect
in vec4 v_clip_rect;

in vec2 v_quad_half_size;
in vec2 v_local_pos;
in vec2 v_tex_coords;
flat in int v_tex_slot;
flat in int v_quad_type;
flat in float v_stroke_thickness;
in vec4 v_border;
in vec4 v_border_radius;

out vec4 o_color;

uniform vec2 u_resolution;

uniform sampler2D u_font_texture;

// Quad type constants (must match Quad_Type enum in backend)
const int QUAD_TYPE_RECT      = 0;
const int QUAD_TYPE_TEXT      = 1;
const int QUAD_TYPE_IMAGE     = 2;
const int QUAD_TYPE_CHECKMARK = 3;

uniform sampler2D u_image_texture_1;
uniform sampler2D u_image_texture_2;
uniform sampler2D u_image_texture_3;
uniform sampler2D u_image_texture_4;
uniform sampler2D u_image_texture_5;

// p: The current fragment's position relative to the center
// a: Start point of the line segment
// b: End point of the line segment
float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - (ba * h));
}

// Calculates alpha based on signed distance for smooth anti-aliasing
// d: The signed distance from the edge
// Returns alpha (1.0 for inside and 0.0 for outside, smooth transition on the edge).
float sdfAlpha(float d) {
    // Use length of gradient for stable AA at corners where gradient direction changes
    vec2 grad = vec2(dFdx(d), dFdy(d));
    float width = length(grad);
    // Ensure minimum AA width of 0.5 pixels to avoid jagged edges
    width = max(width, 0.5);

    return smoothstep(width, -width, d);
}

// Signed Distance Function for a rounded rectangle with variable corner radii.
// pos: The current fragment's position relative to the center.
// halfSize: Half the width and height of the rectangle.
// radii: Corner radii (x=top-left, y=top-right, z=bottom-right, w=bottom-left)
// Returns a negative value inside the rectangle, positive outside, and 0 on the edge.
float sdfRectVariableRadius(vec2 pos, vec2 halfSize, vec4 radii) {
    // Determine which corner's radius to use based on the quadrant
    // quadrant: (+x, +y) = top-right, (-x, +y) = top-left,
    //           (+x, -y) = bottom-right, (-x, -y) = bottom-left
    float r = (pos.x > 0.0)
        ? (pos.y > 0.0 ? radii.y : radii.z)  // right side: top-right or bottom-right
        : (pos.y > 0.0 ? radii.x : radii.w); // left side: top-left or bottom-left

    vec2 d = abs(pos) - (halfSize - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

vec4 calcGradientColor(vec4 color_start, vec4 color_end, vec2 dir, vec2 half_size, vec2 pos) {
    // Handle solid colors (zero-length direction vector)
    float dir_length = length(dir);
    if (dir_length < 0.001) {
        return color_start;
    }

    vec2 u = normalize(dir);

    float proj = dot(pos, u);

    // NOTE(Thomas): We use abs(u) here to ensure that max_proj will be positive, since
    // this is essentially the max length, and negative length doesn't make sense.
    float max_proj = dot(half_size, abs(u));

    float t = (proj + max_proj) / (2.0 * max_proj);

    return mix(color_start, color_end, clamp(t, 0.0, 1.0));
}

// Checks if the current pixel is outside the clipping rectangle (x, y, w, h)
void apply_clip(vec4 rect) {
    // Correctly flip Y to match UI coordinates (Top-Left 0,0)
    vec2 pos = vec2(gl_FragCoord.x, u_resolution.y - gl_FragCoord.y);

    // rect.z = width, rect.w = h
    // min = rect.xy
    // max = rect.xy + rect.zw
    if (any(lessThan(pos, rect.xy)) || any(greaterThan(pos, rect.xy + rect.zw))) {
        discard;
    }
}

void render_rect() {
    float border_sum = v_border.x + v_border.y + v_border.z + v_border.w;

    if (border_sum <= 0.001) {
        // No border - simple path
        float d = sdfRectVariableRadius(v_local_pos, v_quad_half_size, v_border_radius);
        float alpha = sdfAlpha(d);

        vec4 color = calcGradientColor(
            v_color_start,
            v_color_end,
            v_gradient_dir,
            v_quad_half_size,
            v_local_pos
        );

        o_color = vec4(color.rgb, color.a * alpha);
    } else {
        // With border
        // v_border mapping: x=top, y=right, z=bottom, w=left
        vec2 border_offset = vec2(
            (v_border.w - v_border.y) * 0.5,  // X: (left - right) / 2
            (v_border.x - v_border.z) * 0.5   // Y: (top - bottom) / 2
        );

        vec2 border_reduction = vec2(
            (v_border.y + v_border.w) * 0.5,  // X: (right + left) / 2
            (v_border.x + v_border.z) * 0.5   // Y: (top + bottom) / 2
        );

        vec2 inner_half_size = v_quad_half_size - border_reduction;

        // Reduce inner border radius to account for border width
        // This ensures circles stay circular even with thick borders
        float avg_border = (v_border.x + v_border.y + v_border.z + v_border.w) * 0.25;
        vec4 inner_radius = max(v_border_radius - vec4(avg_border), vec4(0.0));

        float d_border = sdfRectVariableRadius(v_local_pos, v_quad_half_size, v_border_radius);
        float d_inner = sdfRectVariableRadius(v_local_pos - border_offset, inner_half_size, inner_radius);

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
            inner_half_size,
            v_local_pos - border_offset
        );

        o_color = mix(o_color, border_color, alpha_border);
        o_color = mix(o_color, inner_color, alpha_inner);
    }
}

void render_text() {
    float alpha = texture(u_font_texture, v_tex_coords).r;
    o_color = vec4(v_color_start.rgb, v_color_start.a * alpha);
}

void render_image() {
    switch (v_tex_slot) {
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

void render_checkmark() {
    // Two line segments forming a check mark
    vec2 p1 = vec2(-0.35, 0.0) * v_quad_half_size;    // Left point
    vec2 p2 = vec2(-0.05, 0.35) * v_quad_half_size;   // Bottom point
    vec2 p3 = vec2(0.40, -0.35) * v_quad_half_size;   // Top-right point

    float d1 = sdSegment(v_local_pos, p1, p2);
    float d2 = sdSegment(v_local_pos, p2, p3);
    float d = min(d1, d2);

    float half_thickness = v_stroke_thickness * 0.5;
    float stroked_d = d - half_thickness;

    float alpha = sdfAlpha(stroked_d);

    vec4 color = calcGradientColor(
        v_color_start,
        v_color_end,
        v_gradient_dir,
        v_quad_half_size,
        v_local_pos
    );

    o_color = vec4(color.rgb, color.a * alpha);
}

void main() {
    apply_clip(v_clip_rect);

    switch (v_quad_type) {
        case QUAD_TYPE_RECT:
            render_rect();
            break;
        case QUAD_TYPE_TEXT:
            render_text();
            break;
        case QUAD_TYPE_IMAGE:
            render_image();
            break;
        case QUAD_TYPE_CHECKMARK:
            render_checkmark();
            break;
    }
}

