# Post Effect Resource

Godot 4.7向け。複数のポストプロセスエフェクトを `.tres` の配列に並べるだけで、順序どおりに適用する。中間バッファ管理は不要。Forward+では`CompositorEffect`、Mobile/Compatibilityでは`CanvasLayer`経路を同じエフェクト定義から利用できる。

このアドオンは「ポストエフェクト集」ではない。同梱の10エフェクトは動く見本であり、主商品は**複数エフェクトを順序付きで安全に積み重ねる仕組み（EffectStackResource / EffectStackRunner）**である。

- 対応バージョン: Godot 4.7 / 4.7.1 で検証済み（4.8-devは追跡中）
- ライセンス: MIT
- `CompositorEffect`はドキュメント上Experimentalだが、2023-08の導入以降、公開APIに破壊的変更は一度もない（2026-08時点）

---

## できないこと

- Forward+ / Mobile経路の自動切り替えは**未実装**。ユーザーが手動で経路を選ぶ
- `Outline`は深度バッファを要するため、canvas（Mobile/Compatibility）経路に代替がない
- `Bloom`のcanvas版はsingle-pass近似であり、compute版と見た目が一致しない
- `Compatibility`レンダラーは`CompositorEffect`自体が非対応（canvas経路のみ利用可）

---

## クイックスタート

1. `addons/post_effect_resource/` をプロジェクトにコピーし、プラグインを有効化する
2. `EffectStackResource` を新規作成し、Inspectorで使いたいエフェクト（`.tres`、例: `effects/vignette/vignette.tres`）を`effects`配列に追加する
3. `WorldEnvironment` の `Compositor` に `EffectStackRunner`（`CompositorEffect`）を追加し、`stack_resource` に上記のリソースを割り当てる
4. エディタの3Dビューポートでプレビューされる（`@tool`対応）

---

## エフェクトを2つ以上積む手順

`EffectStackResource.effects` は配列であり、**先頭から順にin-place実行**される。後段のエフェクトほど最終的な見た目に強く反映される。

```text
screen_color → effects[0] → effects[1] → effects[2] → screen_color
```

Inspectorで要素をドラッグすれば順序を変えられ、保存すれば順序は保持される。追加・削除もInspectorの配列編集UIで行う。

### 順序が結果を変える例

`Grayscale`（彩度を落とす）と`Vignette`（青系の色付き減光）を異なる順序で積むと、最終画像が明確に変わる。

| `[Grayscale, Vignette]` | `[Vignette, Grayscale]` |
|---|---|
| ![Grayscale→Vignette](demo/screenshots/03_order_grayscale_then_vignette.png) | ![Vignette→Grayscale](demo/screenshots/04_order_vignette_then_grayscale.png) |
| Vignetteが最後に効くため、画面端に青みが残る | Grayscaleが最後に効くため、Vignetteの色情報も失われ全体がグレーになる |

3エフェクトのスタック例（`Vignette + Scanline + Grain`）:

![3-effect stack](demo/screenshots/02_pattern_a_vignette_scanline_grain.jpg)

マルチパスエフェクト（`Bloom`）も同じスタックに混在できる:

![Bloom + Vignette](demo/screenshots/05_bloom_vignette.png)

### callback_typeについて

Godotの`CompositorEffect.EffectCallbackType`はビットフラグではなく単一のenum値である。したがって:

- **1つの`EffectStackRunner`は1つの`effect_callback_type`のみを担当する**（Inspectorで選択）
- 各エフェクトの`effect_callback_type`がRunnerの設定と一致する場合のみ実行される
- 複数stage（例: `POST_SKY`と`POST_TRANSPARENT`の両方）でエフェクトを実行したい場合は、**Compositorに複数の`EffectStackRunner`を登録**する

### 有効/無効の切り替え

各エフェクトの`enabled`フラグをOFFにすると、そのエフェクトだけがスタックから即座に除外される（追加のシグナル接続は不要）。

---

## エフェクト作成ガイド

新しいエフェクトは以下3ファイルで構成する（`effects/vignette/`等が実例）。

1. `<name>.gd` — `PostEffectResource`を継承し、`_build_push_constant()`でシェーダに渡すパラメータを組み立てる
2. `<name>.glsl` — `addons/post_effect_resource/shaders/template_post_effect.glsl`の`#COMPUTE_CODE`置換方式で書くcompute shader
3. `<name>.tres` — デフォルトパラメータのプリセットResource

深度バッファが必要な場合は`needs_depth = true`を設定する。マルチパスが必要な場合（`Bloom`参照）は`_is_multi_pass = true`を設定し、`_render_multi_pass()`を実装する。単一パスエフェクトはこの実装は不要。

`needs_depth = true`の場合、depthバッファは`binding = 1`に自動バインドされる。`_get_additional_uniforms()`で独自uniformを追加する場合、`needs_depth = true`と組み合わせるなら`binding = 2`以降を使うこと（衝突する）。

Mobile/Compatibility向けのcanvas経路を提供する場合は、`<name>_canvas.gdshader`（`hint_screen_texture`ベース）を追加し、`addons/post_effect_resource/canvas_post_effect.tscn`の`effect_material`に割り当てる。深度依存エフェクトはcanvas経路を提供できない。

---

## 既存の単体シェーダをこの形式に載せ替える手順

godotshaders.com等で配布されている単体のポストプロセスシェーダを本形式に移植する場合:

1. シェーダのフラグメント/コンピュート処理本体を`<name>.glsl`の`#COMPUTE_CODE`部分に移す
2. シェーダのuniformパラメータを`<name>.gd`の`@export`プロパティに対応させ、`_build_push_constant()`でpush constantとして渡す
3. `<name>.tres`にデフォルト値を設定する
4. `EffectStackResource.effects`に追加すれば、他のエフェクトと順序付きで組み合わせられるようになる

これにより、単体シェーダを2つ以上重ねる際に必要だった`BackBufferCopy` + `Viewport`の手作業構成が不要になる。

---

## Renderer対応マトリクス

| 機能 | Forward+ | Mobile | Compatibility |
|---|---:|---:|---:|
| `CompositorEffect` API | 対応 | 対応 | 非対応 |
| 本アドオンのcompute経路 | 対応 | 未保証（[godot#96737](https://github.com/godotengine/godot/issues/96737)） | 非対応 |
| depth / normal-roughness アクセス | 対応 | 個別検証 | 非対応 |
| canvas経路（フォールバック） | 対応 | 対応 | 対応 |
| エディタプレビュー | `@tool`で対応 | 個別検証 | canvas経路のみ |

Mobile実機での各エフェクトのcanvas経路動作確認は完了済み（Grayscale / Vignette / ChromaticAberration / Scanline / Grain / Pixelate / Dither / Bloom / ColorGrading の9エフェクト。`scenes/mobile_test/`の各デモシーンで確認可能）。

---

## 収録エフェクト

| エフェクト | 必要バッファ | compute | canvas |
|---|---|:---:|:---:|
| Grayscale | Color | ○ | ○ |
| Vignette | Color | ○ | ○ |
| ColorGrading (LUT) | Color | ○ | △（LUTはGradientTexture2Dインライン） |
| ChromaticAberration | Color | ○ | ○ |
| Scanline | Color | ○ | ○ |
| Grain/Noise | Color | ○ | ○ |
| Pixelate | Color | ○ | ○ |
| Bloom | Color（マルチパス） | ○ | △（single-pass近似） |
| Dither | Color | ○ | ○ |
| Outline | Color + Depth | ○ | 不可（深度バッファ非対応） |

---

## APIリファレンス（概要）

### `PostEffectResource`（`addons/post_effect_resource/post_effect_resource.gd`）

単一エフェクトの定義。`Resource`を継承。

| メンバ | 用途 |
|---|---|
| `shader_file: RDShaderFile` | compute shader参照 |
| `effect_callback_type` | `POST_TRANSPARENT`等、実行stage |
| `needs_depth: bool` | depthバッファバインドの要否 |
| `enabled: bool` | 有効/無効 |
| `_build_push_constant(screen_size, view)` | サブクラスでオーバーライドし、シェーダへ渡す値を組み立てる |
| `_get_additional_uniforms()` | テクスチャ等の追加uniformが必要な場合にオーバーライド |
| `_is_multi_pass` / `_render_multi_pass(...)` | マルチパスエフェクト用（`Bloom`参照） |

### `PostEffectRunner`（`addons/post_effect_resource/post_effect_runner.gd`）

単一の`PostEffectResource`を実行する`CompositorEffect`。単一エフェクト用途では`EffectStackRunner`よりオーバーヘッドが小さい。

### `EffectStackResource`（`addons/post_effect_resource/effect_stack_resource.gd`）

`effects: Array[PostEffectResource]` を保持するResource。Inspectorで並び替え・追加・削除ができる。

### `EffectStackRunner`（`addons/post_effect_resource/effect_stack_runner.gd`）

`EffectStackResource`を受け取り、`enabled`かつ`effect_callback_type`が一致するエフェクトを配列順に実行する`CompositorEffect`。シェーダ・パイプラインはリソースパスをキーにキャッシュされる。

---

## ライセンス

MIT License. `LICENSE`ファイルを参照。

参考実装として一部アルゴリズムを参照した箇所があるが、ライセンス条件が異なる実装（Rokojori Public Indie License等）からのコード流用は行っていない。
