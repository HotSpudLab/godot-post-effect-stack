#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float padding;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }
    vec4 color = imageLoad(color_image, uv);
    float gray = dot(color.rgb, vec3(0.2125, 0.7154, 0.0721));
    imageStore(color_image, uv, vec4(vec3(gray), color.a));
}
