#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
layout(set = 0, binding = 1, rgba8) uniform image2D bloom_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
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
    vec4 col = imageLoad(color_image, uv);
    vec4 bloom = imageLoad(bloom_image, uv);
    vec3 result = col.rgb + bloom.rgb * pc.intensity;
    imageStore(color_image, uv, vec4(result, col.a));
}
