#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform image2D color_image;

layout(push_constant, std430) uniform PushConstant {
    vec4 screen_size_view;
    vec4 adjustments; // brightness, contrast, hue degrees, saturation
} pc;

vec3 linear_to_srgb(vec3 color) {
    color = max(color, vec3(0.0));
    bvec3 cutoff = lessThanEqual(color, vec3(0.0031308));
    vec3 lower = color * 12.92;
    vec3 higher = 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055;
    return mix(higher, lower, cutoff);
}

vec3 srgb_to_linear(vec3 color) {
    bvec3 cutoff = lessThanEqual(color, vec3(0.04045));
    vec3 lower = color / 12.92;
    vec3 higher = pow(max((color + 0.055) / 1.055, vec3(0.0)), vec3(2.4));
    return mix(higher, lower, cutoff);
}

vec3 rgb_to_hsv(vec3 c) {
    vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
    vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    vec2 screen_size = pc.screen_size_view.xy;
    if (pixel.x >= int(screen_size.x) || pixel.y >= int(screen_size.y)) {
        return;
    }

    // Preserve the input bytes, including HDR and alpha, at the neutral settings.
    // A linear/sRGB/HSV round trip can change half-float values even at zero.
    if (all(equal(pc.adjustments, vec4(0.0)))) {
        return;
    }

    vec4 source = imageLoad(color_image, pixel);
    vec3 display = linear_to_srgb(source.rgb);
    display += vec3(pc.adjustments.x);
    display = (display - vec3(0.5)) * (1.0 + pc.adjustments.y) + vec3(0.5);

    vec3 hsv = rgb_to_hsv(max(display, vec3(0.0)));
    hsv.x = fract(hsv.x + pc.adjustments.z / 360.0);
    hsv.y = clamp(hsv.y * (1.0 + pc.adjustments.w), 0.0, 1.0);
    display = hsv_to_rgb(hsv);

    imageStore(color_image, pixel, vec4(srgb_to_linear(max(display, vec3(0.0))), source.a));
}
