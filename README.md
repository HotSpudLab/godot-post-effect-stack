# Post Effect Stack

Formerly "Post Effect Resource".

For Godot 4.7. Stack multiple post-processing effects by arranging them in a `.tres` array — applied in order, with no manual intermediate buffer management. Uses `CompositorEffect` on Forward+, and a `CanvasLayer` path on Mobile/Compatibility, from the same effect definitions. See [What it can't do](#what-it-cant-do) for the Mobile and MSAA constraints before choosing a path.

This addon is not an "effect collection". The bundled 10 effects are working samples — the real product is the mechanism for stacking multiple effects safely and in order (`EffectStackResource` / `EffectStackRunner`).

- Supported versions: verified on Godot 4.7 / 4.7.1 (4.8-dev tracked). Patch releases within a verified minor (4.7.x) are treated as supported on API-compatibility grounds; a new minor is verified before it is declared supported
- License: MIT
- `CompositorEffect` is documented as Experimental, but its public API hasn't had a single breaking change since its introduction in 2023-08 (as of 2026-08)

---

## What it can't do

- Automatic switching between the compute and canvas paths is **not implemented**. You must choose the path manually
- The compute path targets **Forward+**. On the Mobile renderer it does not apply (see below); on `Compatibility`, `CompositorEffect` does not exist at all. Use the canvas path for both
- `Outline` requires a depth buffer, so there's no canvas (Mobile/Compatibility) fallback
- `Bloom`'s canvas version is a single-pass approximation and won't exactly match the compute version
- With **MSAA 3D enabled**, only the `POST_TRANSPARENT` callback stage applies. That is this addon's default, so the out-of-the-box setup is unaffected — but a custom `effect_callback_type` will silently do nothing
- With MSAA 3D enabled, `Outline`'s edges thin out and break into dashes as the MSAA level rises

### Measured behaviour behind those last three points

These are engine-side behaviours, not something this addon can work around. Both are open
upstream issues that have persisted across several releases, so they are unlikely to
disappear in a patch version:

| What | Measured on Godot 4.7 | Upstream |
|---|---|---|
| Mobile renderer, compute path | No effect applies. The engine reports the colour buffer lacks `TEXTURE_USAGE_STORAGE_BIT`, so the compute shader cannot write to it | [godot#96737](https://github.com/godotengine/godot/issues/96737) (open, filed against 4.3) |
| MSAA 3D on Forward+ | The callback still fires at every stage, but writes made anywhere other than `POST_TRANSPARENT` are discarded | [godot#106743](https://github.com/godotengine/godot/issues/106743) (open, filed against 4.4) |
| MSAA 3D + `Outline` | Outlined pixels drop to roughly 59% / 37% / 26% of the MSAA-off amount at 2x / 4x / 8x | same as above (depth side) |

Measured on Windows / D3D12 / NVIDIA, Godot 4.7.stable. **The Mobile result is for the
Mobile *rendering method*; it was not re-checked on Android hardware.** The canvas path,
which is the recommended path there, has been verified on real Mobile hardware for 9 effects.

---

## Folder structure

| Folder | Required | Contents |
|---|---|---|
| `addons/post_effect_stack/` | Required | The engine itself (Resource base class, Runner, shader template). Contains zero effects |
| `effects/` | Required (if using the bundled 10 effects) | Working sample effect implementations. Not needed if you only use your own effects |
| `demo/`, `scenes/` | Optional | Demo scenes for verifying behavior. Not needed to integrate into your project |
| `LICENSE` | Optional | Full MIT license text |

Note this isn't a "plugin-only" layout — it's a framework structure that separates `addons/` (the mechanism) from `effects/` (the content).

---

## Quick start

1. Copy both `addons/post_effect_stack/` (the engine) and `effects/` (the bundled effect collection) into your project, and enable the plugin
2. Create a new `EffectStackResource`, and in the Inspector add the effects you want (`.tres`, e.g. `effects/vignette/vignette.tres`) to the `effects` array
3. Add an `EffectStackRunner` (`CompositorEffect`) to `WorldEnvironment`'s `Compositor`, and assign the resource above to `stack_resource`
4. Previewed live in the editor's 3D viewport (`@tool` supported)

---

## Stacking two or more effects

`EffectStackResource.effects` is an array, and it's **executed in-place, in order from the first element**. Effects later in the array have a stronger influence on the final look.

```text
screen_color → effects[0] → effects[1] → effects[2] → screen_color
```

Drag elements in the Inspector to reorder them; the order is preserved on save. Add/remove is also done through the Inspector's array editing UI.

### Example: order changes the result

Stacking `Grayscale` (desaturates) and `ColorGrading` (applies a LUT) in different orders visibly changes the final image.

| `[Grayscale, ColorGrading]` | `[ColorGrading, Grayscale]` |
|---|---|
| ![Grayscale→ColorGrading](demo/screenshots/03_order_grayscale_then_colorgrading.png) | ![ColorGrading→Grayscale](demo/screenshots/04_order_colorgrading_then_grayscale.png) |
| ColorGrading applies last, so its LUT tints the already-desaturated image a single hue | Grayscale applies last, so ColorGrading's color is discarded too and the image turns neutral gray |

Order also changes which effect "wins" when one depends on geometry and the other on pixels. `Outline` reads the depth buffer, `Pixelate` reads only color, so stacking them either preserves or destroys the outline depending on order:

| `[Pixelate, Outline]` | `[Outline, Pixelate]` |
|---|---|
| ![Pixelate→Outline](demo/screenshots/05_order_pixelate_then_outline.png) | ![Outline→Pixelate](demo/screenshots/06_order_outline_then_pixelate.png) |
| Outline draws last on top of the already-blocky image, so the line stays crisp and continuous | Outline draws first and Pixelate then blockifies it too, breaking the line into disconnected chunks |

Example 5-effect stack (`Pixelate + ColorGrading + Scanline + Vignette + Grain`):

![5-effect stack](demo/screenshots/02_pattern_retro_crt.webp)

### About `callback_type`

Godot's `CompositorEffect.EffectCallbackType` is a single enum value, not a bit flag. As a result:

- **One `EffectStackRunner` handles exactly one `effect_callback_type`** (chosen in the Inspector)
- Each effect only runs if its `effect_callback_type` matches the Runner's setting
- To run effects at multiple stages (e.g. both `POST_SKY` and `POST_TRANSPARENT`), **register multiple `EffectStackRunner`s on the Compositor**

### Enabling/disabling

Turning off an effect's `enabled` flag immediately excludes just that effect from the stack (no extra signal wiring needed).

---

## Effect authoring guide

A new effect is made up of the following 3 files (see `effects/vignette/` etc. for real examples).

1. `<name>.gd` — extends `PostEffect` and builds the parameters passed to the shader in `_build_push_constant()`
2. `<name>.glsl` — a compute shader written using the `#COMPUTE_CODE` substitution in `addons/post_effect_stack/shaders/template_post_effect.glsl`
3. `<name>.tres` — a preset Resource holding the default parameters

Set `needs_depth = true` if a depth buffer is required. For multi-pass effects (see `Bloom`), set `_is_multi_pass = true` and implement `_render_multi_pass()`. Single-pass effects don't need this.

> **If your effect reads any pixel other than the one it writes, it must not read `color_image` directly.** Effects run in place on the colour buffer, so within a single dispatch a neighbouring workgroup may already have overwritten the pixel you want to sample — the output then depends on execution order and changes from frame to frame. Set `needs_source_snapshot = true` instead and sample the snapshot the runner binds for you (see below). Effects that only touch their own pixel — `Grayscale`, `Vignette`, `Dither`, … — are unaffected.

### Source snapshots

Set `needs_source_snapshot = true` and the runner copies the colour buffer into a separate texture before your effect runs, then binds it as a `sampler2D`:

```glsl
layout(set = 0, binding = 0, rgba8) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D source_image;
```

Nothing writes to that texture while your dispatch reads it, so displaced reads are safe. It is a sampled texture rather than a storage image, so `texture()` gives you filtered reads at fractional offsets — `imageLoad()` cannot do that. `effects/chromatic_aberration/` is the shipped example.

The snapshot costs one full-screen compute dispatch per effect that asks for it (measured at about 60 µs for 960×540 on an RTX 2060-class GPU), so only set the flag when you actually sample outside your own pixel.

### Binding order

The colour buffer is always `binding = 0`. What follows depends on which flags the effect sets:

| Flags set | 0 | 1 | 2 | 3 and up |
|---|---|---|---|---|
| (none) | `color_image` | your uniforms | your uniforms | your uniforms |
| `needs_depth` | `color_image` | `depth_image` | your uniforms | your uniforms |
| `needs_source_snapshot` | `color_image` | `source_image` | your uniforms | your uniforms |
| both | `color_image` | `source_image` | `depth_image` | your uniforms |

Uniforms you return from `_get_additional_uniforms()` must use the first free binding in that table and count up from there.

To provide a canvas path for Mobile/Compatibility, add a `<name>_canvas.gdshader` (based on `hint_screen_texture`) and assign it to `effect_material` on `addons/post_effect_stack/canvas_post_effect.tscn`. Depth-dependent effects can't provide a canvas path.

---

## Porting an existing standalone shader to this format

To port a standalone post-processing shader (e.g. one distributed on godotshaders.com) into this format:

1. Move the shader's fragment/compute body into the `#COMPUTE_CODE` section of `<name>.glsl`
2. Map the shader's uniform parameters to `@export` properties on `<name>.gd`, and pass them as a push constant in `_build_push_constant()`
3. Set the default values in `<name>.tres`
4. Add it to `EffectStackResource.effects`, and it can now be combined with other effects in order

This removes the need for the manual `BackBufferCopy` + `Viewport` setup normally required to stack two or more standalone shaders.

### What those four steps don't cover

The steps above are enough for a shader that reads only its own pixel and does no colour-space-sensitive maths. Porting sessions on real godotshaders.com shaders hit three things that the steps do not mention. All three are listed here because **none of them produce an error or a warning** — you get a plausible-looking but wrong image, so there is nothing to search for.

**1. Colour space differs from the canvas path.** A `canvas_item` shader reading `hint_screen_texture` sees post-tonemap sRGB values. This addon's compute path writes into the pre-tonemap linear HDR buffer (`RGBA16F`), so it sees linear values, and values above 1.0 exist. On top of that, the `source_color` hint on a canvas uniform silently converts that uniform from sRGB to linear for you; a push constant does not. If the original shader does anything that assumes sRGB — hue/saturation maths, palette matching, threshold comparisons — convert to sRGB first, do the maths, and convert back before writing. Symptom when you skip this: the effect works, but the colours are off (e.g. a deep blue comes out cyan).

**2. Sampling any pixel other than your own needs a snapshot.** Effects run in place on the colour buffer, so reading a neighbour is not safe — see the note in the effect authoring guide above. `needs_source_snapshot = true` covers this: shaders that rely on smooth UV sampling (distortion, blur, shockwave, chromatic aberration) get a snapshot bound as a `sampler2D`, which is filtered, so their `texture()` calls port across as they are. `imageLoad()` on `color_image` remains unfiltered and integer-only.

**3. Extra textures are not just an `@export`.** To bind a texture (LUT, palette, noise) alongside the colour buffer, return a `UNIFORM_TYPE_SAMPLER_WITH_TEXTURE` uniform from `_get_additional_uniforms()`, built from `RenderingServer.texture_get_rd_texture(tex.get_rid())`, and create the sampler yourself with an `RDSamplerState` passed to `RenderingDevice.sampler_create()`. **You own that sampler and must free it** on `NOTIFICATION_PREDELETE`. For the binding number, see the rule in the authoring guide above. `effects/color_grading/color_grading.gd` is the shipped example — it binds three LUT textures at bindings 1–3 with one shared linear sampler.

### Shaders that need more than a port

- **Anything using `TIME`.** There is no automatic time uniform. Add a `time` field to your push constant and advance it from outside the effect — `effects/grain/` and `demo/grain_demo.gd` show the smallest version of this.
- **Anything using screen-space derivatives (`dFdx`/`dFdy`)** or built-ins that only exist in `canvas_item`/`spatial` shaders. These have no direct equivalent in the compute path and need rewriting, not porting.
- **Depth-dependent effects on Mobile/Compatibility.** See the renderer support matrix below.

---

## Renderer support matrix

| Feature | Forward+ | Mobile | Compatibility |
|---|---:|---:|---:|
| `CompositorEffect` API | Supported | Supported | Not supported |
| This addon's compute path | Supported | **Does not apply** — measured on 4.7 ([godot#96737](https://github.com/godotengine/godot/issues/96737)) | Not supported |
| depth / normal-roughness access | Supported (degrades with MSAA) | Not supported for the compute path | Not supported |
| canvas path (fallback) | Supported | Supported | Supported |
| Editor preview | Supported via `@tool` | Verified case-by-case | canvas path only |

The canvas path has been verified working on real Mobile hardware for 9 effects (Grayscale / Vignette / ChromaticAberration / Scanline / Grain / Pixelate / Dither / Bloom / ColorGrading — see the demo scenes under `scenes/mobile_test/`).

---

## Included effects

| Effect | Buffers needed | compute | canvas |
|---|---|:---:|:---:|
| Grayscale | Color | ○ | ○ |
| Vignette | Color | ○ | ○ |
| ColorGrading (LUT) | Color | ○ | △ (LUT is an inline GradientTexture2D) |
| ChromaticAberration | Color | ○ | ○ |
| Scanline | Color | ○ | ○ |
| Grain/Noise | Color | ○ | ○ |
| Pixelate | Color | ○ | ○ |
| Bloom | Color (multi-pass) | ○ | △ (single-pass approximation) |
| Dither | Color | ○ | ○ |
| Outline | Color + Depth | ○ | Not possible (depth buffer not supported) |

---

## API reference (overview)

### `PostEffect` (`addons/post_effect_stack/post_effect.gd`)

Defines a single effect. Extends `Resource`.

| Member | Purpose |
|---|---|
| `shader_file: RDShaderFile` | Reference to the compute shader |
| `effect_callback_type` | Execution stage, e.g. `POST_TRANSPARENT` |
| `needs_depth: bool` | Whether the depth buffer needs to be bound |
| `needs_source_snapshot: bool` | Bind a pre-effect copy of the colour buffer as a filtered `sampler2D`. Required to sample any pixel other than your own |
| `enabled: bool` | Enable/disable |
| `_build_push_constant(screen_size, view)` | Override in a subclass to build the values passed to the shader |
| `_get_additional_uniforms()` | Override when additional uniforms (e.g. textures) are needed |
| `_is_multi_pass` / `_render_multi_pass(...)` | For multi-pass effects (see `Bloom`) |

### `PostEffectRunner` (`addons/post_effect_stack/post_effect_runner.gd`)

A `CompositorEffect` that runs a single `PostEffect`. Lower overhead than `EffectStackRunner` for single-effect use.

### `EffectStackResource` (`addons/post_effect_stack/effect_stack_resource.gd`)

A Resource holding `effects: Array[PostEffect]`. Supports reordering, adding, and removing in the Inspector.

### `EffectStackRunner` (`addons/post_effect_stack/effect_stack_runner.gd`)

A `CompositorEffect` that takes an `EffectStackResource` and runs the effects, in array order, that are `enabled` and whose `effect_callback_type` matches. Shaders/pipelines are cached keyed by resource path.

---

## Migrating from an older version

`v0.2.0` renamed the addon from "Post Effect Resource" to "Post Effect Stack" and changed paths/class names. There is no compatibility shim — update your project as follows:

1. Delete the old `addons/post_effect_resource/` directory from your project.
2. Copy in the new `addons/post_effect_stack/` directory (and update `effects/` if you use the bundled effects).
3. If you wrote a custom effect that extended `PostEffectResource`, change it to extend `PostEffect` instead. The base class was renamed; its members and behavior are unchanged.
4. Re-enable the plugin in Project Settings > Plugins if it was disabled after the directory swap (Godot may deactivate a plugin whose folder disappeared).
5. Any `.tres` / `.tscn` files that reference `res://addons/post_effect_resource/...` paths need to be repointed to `res://addons/post_effect_stack/...` (Godot's path remap on file move usually handles this automatically if you move files within the same project; a manual copy-in does not).

No other classes were renamed: `PostEffectRunner`, `EffectStackResource`, and `EffectStackRunner` keep their names.

---

## License

MIT License. See the `LICENSE` file.

Some algorithms were referenced from existing implementations for research purposes, but no code was reused from implementations under different license terms (e.g. the Rokojori Public Indie License).
