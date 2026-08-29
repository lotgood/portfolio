# Technical Notes

## Rendering architecture

```text
Astro static HTML + native CSS
             │
             ├─ always visible CSS fallback
             │
             └─ idle bootstrap
                    │ capability / preference checks
                    ▼
              dynamic import
                    ▼
             vgpu + WGSL hero
```

The GPU renderer is deliberately isolated in `src/gpu/hero-runtime.ts`. Components and content do not import vgpu.

## Progressive-enhancement matrix

| Environment | Result |
|---|---|
| WebGPU + capable desktop | Full shader, capped DPR, 60 fps request |
| WebGPU + ordinary/mobile hardware | Fewer shader layers, lower DPR, 30–60 fps request |
| Data Saver enabled | CSS fallback only |
| Reduced motion enabled | CSS fallback only |
| No WebGPU / initialization error | CSS fallback only |
| Background tab or hero offscreen | Render loop stopped |

Capability heuristics only choose a safe starting profile. A small frame-time controller may reduce shader layers, but it never raises quality above the initial profile.

## Performance budgets

The production budget check in `scripts/check-budgets.mjs` enforces:

- Initial JavaScript: **40 KiB gzip or less**
- Initial CSS: **32 KiB gzip or less**
- Total built JavaScript, including the lazy GPU chunk: **110 KiB gzip or less**
- Each generated HTML document: **80 KiB raw or less**

These are guardrails, not targets. Prefer staying materially below them.

## Performance rules

- No remote font request in P0.
- No video in the initial viewport.
- Use one canvas and one fullscreen pass.
- Set only per-frame uniforms in the render loop.
- Keep resize-class values in the resize callback.
- Cap device pixel ratio instead of blindly using the display DPR.
- Pause work with document visibility and intersection state.
- Lower math complexity before adding post-processing.
- Measure before adding an optimization dependency.

## HDR boundary

P0 uses wide-gamut CSS where supported and performs controlled SDR tone mapping inside the WGSL shader. It **does not claim true HDR canvas presentation**.

A future HDR pass may add:

1. linear `rgba16float` intermediate rendering,
2. a verified extended-range canvas presentation path,
3. explicit SDR tone-map fallback,
4. browser-and-display capability tests,
5. screenshot/measurement evidence proving that values above reference white survive presentation.

Do not label the site HDR until those five conditions are met. Keep the output stage replaceable so this can be added without rewriting the authored visual.

## Validation path

```bash
pnpm check       # Astro diagnostics + WGSL static validation
pnpm build       # static production output
pnpm budget      # compressed bundle and HTML limits
pnpm validate    # all three
pnpm gpu:doctor  # real adapter/render health, separately
```

Visual acceptance still requires testing on at least:

- Safari on Apple Silicon
- Chromium on a discrete or integrated GPU
- a phone-sized viewport
- reduced-motion mode
- a browser with WebGPU disabled

## Reference boundary

- [FragCoord / Xor tutorials](https://fragcoord.xyz/u/Xor?tab=tutorials) inform shader authoring and iteration. FragCoord is not a production dependency.
- [vgpu](https://github.com/vercel-labs/vgpu) supplies the small WebGPU runtime and WGSL tooling used by this scaffold.
- [ABYSSAL / natural-disasters](https://github.com/Token-Gremlin/natural-disasters) is an architectural reference for procedural rendering and adaptive quality only. No source from that project is included here.

Treat every third-party shader or code sample as separately licensed material. Record the source, license, modifications, and required attribution before shipping it.
