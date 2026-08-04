#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba8) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec2 screen_size;
    float view;
    float block_size;
} pc;

void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    if (uv.x >= int(pc.screen_size.x) || uv.y >= int(pc.screen_size.y)) {
        return;
    }

    int bs = int(pc.block_size);
    if (bs < 1) bs = 1;

    ivec2 block_uv = (uv / bs) * bs + ivec2(bs / 2);
    block_uv = clamp(block_uv, ivec2(0), ivec2(pc.screen_size) - 1);

    vec4 col = imageLoad(color_image, block_uv);
    imageStore(color_image, uv, col);
}
