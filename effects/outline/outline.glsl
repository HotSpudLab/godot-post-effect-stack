#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float line_width;
    float depth_threshold;
    float line_color_r;
    float line_color_g;
    float line_color_b;
    float padding;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }

    vec2 uv_norm = vec2(float(uv.x), float(uv.y)) / pc.screen_size;
    float center_depth = texture(depth_image, uv_norm).r;
    float max_diff = 0.0;

    int w = int(pc.line_width);
    for (int x = -w; x <= w; x++) {
        for (int y = -w; y <= w; y++) {
            if (x == 0 && y == 0) continue;
            ivec2 sample_uv = clamp(uv + ivec2(x, y), ivec2(0), ivec2(pc.screen_size) - 1);
            vec2 sample_uv_norm = vec2(float(sample_uv.x), float(sample_uv.y)) / pc.screen_size;
            float sample_depth = texture(depth_image, sample_uv_norm).r;
            float diff = abs(center_depth - sample_depth);
            max_diff = max(max_diff, diff);
        }
    }

    vec4 col = imageLoad(color_image, uv);
    float outline = step(pc.depth_threshold, max_diff);
    vec3 line_color = vec3(pc.line_color_r, pc.line_color_g, pc.line_color_b);
    vec3 result = mix(col.rgb, line_color, outline);

    imageStore(color_image, uv, vec4(result, col.a));
}
