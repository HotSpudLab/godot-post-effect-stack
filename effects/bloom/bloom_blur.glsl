#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D src_image;
layout(set = 0, binding = 1, rgba8) uniform image2D dst_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float pass_index;
    float threshold;
    float intensity;
    float blur_radius;
    float blur_passes;
    float padding;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }

    float radius = pc.blur_radius * (1.0 + pc.pass_index * 0.5);
    ivec2 offset = ivec2(int(radius), 0);
    if (int(pc.pass_index) % 2 == 1) {
        offset = ivec2(0, int(radius));
    }

    vec4 sum = vec4(0.0);
    float weights = 0.0;
    for (int i = -3; i <= 3; i++) {
        ivec2 sample_uv = clamp(uv + offset * i, ivec2(0), ivec2(pc.screen_size) - 1);
        float w = exp(-float(i * i) * 0.5);
        sum += imageLoad(src_image, sample_uv) * w;
        weights += w;
    }
    imageStore(dst_image, uv, sum / weights);
}
