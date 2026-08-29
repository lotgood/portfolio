# Technical Notes

## Rendering architecture

```text
Astro static HTML + native CSS
             │
             ├─ always visible CSS fallback
             │
             └─ idle bootstrap (layout level, so every page participates)
                    │ capability / preference checks
                    ▼
              dynamic import
                    ▼
            one vgpu device + one frame loop
                    ├─ hero surface     (src/shaders/hero.wgsl)
                    └─ ambient surface  (src/shaders/ambient.wgsl)
```

The GPU renderer is deliberately isolated in `src/gpu/visuals-runtime.ts`. Components and content do not import vgpu.

Both surfaces share one device and one frame loop, so the second surface costs a draw call rather than a second renderer. The hero draws only while it intersects the viewport. The ambient field runs at half detail while the hero is on screen, and renders below native resolution (roughly 0.6x the hero's DPR) because a volumetric march is fill-rate bound and the result has no hard edges to lose.

The hero's visual is masked to fade out at its bottom edge so the ambient field bleeds through from inside it. Without that, the point where the field appears reads as a horizontal rule.

## Progressive-enhancement matrix

| Environment | Result |
|---|---|
| WebGPU + capable desktop | Full shader, capped DPR, 60 fps request |
| WebGPU + ordinary/mobile hardware | Fewer shader layers, lower DPR, 30–60 fps request |
| Data Saver enabled | CSS fallback only |
| Reduced motion enabled | CSS fallback only |
| No WebGPU / initialization error | CSS fallback only |
| Background tab | Render loop stopped |
| Hero offscreen | Hero surface skipped; ambient field continues |

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

The hero ships a true extended-range (HDR) presentation path, guaranteed only on **Chromium browsers driving an HDR-capable display**. Every other environment (Safari, Firefox, SDR displays, WebGPU-unavailable clients) receives the controlled SDR tone-mapped or CSS fallback — by design, not as a defect.

The implemented path satisfies these conditions:

1. `rgba16float` canvas format carrying values above 1.0: the SDR ACES base is preserved exactly, highlight energy (ribbon cores and stars) is accumulated in a separate `glow` channel and added on top of reference white, and only the portion above 1.0 is rolled off toward the `hero.headroom` ceiling (identity at or below white, so the base image is unchanged),
2. extended-range canvas presentation via `GPUCanvasContext.configure` with `toneMapping: { mode: 'extended' }` and `colorSpace: 'display-p3'` (applied as a re-configure on the vgpu surface context, which vgpu configures once and never overwrites on resize),
3. explicit SDR tone-map fallback (the original ACES + gamma output stage) selected by the same shader,
4. capability gating without UA sniffing: `dynamic-range: high` media query plus a configure-and-read-back probe of `toneMapping` support (`GPUCanvasContext.getConfiguration`),
5. acceptance by owner visual verification on an XDR display: hero highlights must be visibly brighter than a reference-white (`#FFFFFF`) comparison swatch (dev-only `?hdrcheck` overlay). Instrumented luminance measurement is intentionally not required.

The `dynamic-range: high` media query signals display capability only, never that HDR output is active; the live canvas configuration read-back is the source of truth (surfaced in the `data-gpu-status` label as `HDR`).

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
