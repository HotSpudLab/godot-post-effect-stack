#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D lut_r;
layout(set = 0, binding = 2) uniform sampler2D lut_g;
layout(set = 0, binding = 3) uniform sampler2D lut_b;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view_intensity; // x=screen_size.x, y=screen_size.y, z=view, w=intensity
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view_intensity.xy;
    if (uv.x >= int(screen_size.x) || uv.y >= int(screen_size.y)) {
        return;
    }
    vec4 col = imageLoad(color_image, uv);

    float r = texture(lut_r, vec2(col.r, 0.5)).r;
    float g = texture(lut_g, vec2(col.g, 0.5)).g;
    float b = texture(lut_b, vec2(col.b, 0.5)).b;

    vec3 graded = vec3(r, g, b);
    float intensity = pc.screen_size_view_intensity.w;
    vec3 result = mix(col.rgb, graded, intensity);

    imageStore(color_image, uv, vec4(result, col.a));
}
