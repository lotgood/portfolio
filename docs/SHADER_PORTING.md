# FragCoord → vgpu Shader Workflow

## Ownership and licensing first

Use one of these sources only:

1. a shader you authored,
2. a shader with an explicit license that permits the intended use,
3. a shader for which you have written permission.

Record attribution and license before copying code. A public Explore page is not, by itself, permission to ship someone else's shader.

## Stable runtime contract

The portfolio runtime supplies one uniform block named `hero`:

```wgsl
struct HeroParams {
  time: f32,
  aspect: f32,
  scroll: f32,
  quality: f32,
  pointer: vec2f,
  viewport: vec2f,
}

@group(0) @binding(0)
var<uniform> hero: HeroParams;
```

The fragment entry point receives normalized `uv` and returns a color:

```wgsl
@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f
```

Preserve this contract while iterating so shader swaps do not require application changes. vgpu's injected `uv` is top-origin: `(0, 0)` is the top-left and `uv.y` grows downward. If a FragCoord/Shadertoy source assumes a bottom-left origin, flip once at the boundary with `let sourceUv = vec2f(uv.x, 1.0 - uv.y);`.

## Porting sequence

1. Create and tune the visual in FragCoord.
2. Export WGSL when possible; otherwise port the smallest self-contained fragment.
3. Replace FragCoord globals with the `hero` fields above.
4. Convert pixel coordinates with `uv`, `hero.viewport`, and `hero.aspect`.
5. Keep color calculations unclipped internally, then use one explicit output transform.
6. Paste the result into `src/shaders/hero.wgsl`.
7. Run `pnpm check` before opening the browser.
8. Verify low-quality and reduced-motion behavior before increasing detail.

## Translation notes

Common substitutions:

| FragCoord-style input | Portfolio input |
|---|---|
| time / `iTime` | `hero.time` |
| resolution | `hero.viewport` |
| mouse | `hero.pointer` in normalized 0–1 coordinates |
| fragment pixel coordinate | `uv * hero.viewport` |
| page scroll | `hero.scroll` in normalized 0–1 range |

## Shader limits for the hero

- One fragment pass in P0
- No texture downloads
- Prefer four or fewer procedural layers
- Avoid long raymarch loops
- Avoid per-pixel loops whose bound grows with viewport size
- Use `hero.quality` to skip optional layers uniformly
- Keep temporal motion slow enough that the text remains readable
- Do not add bloom until the base composition works without it

## Definition of done for a replacement shader

- `vgpu check` succeeds.
- It remains visually coherent at 0.75 DPR and mobile aspect ratios.
- Low-quality mode is meaningfully cheaper.
- Text contrast remains acceptable throughout the animation.
- There is no visible first-frame flash when canvas replaces the CSS fallback.
- The shader source and any derived work have a recorded license decision.
