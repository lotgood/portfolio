# lotgood — WebGPU Portfolio

lotgood's static-first personal portfolio, built for four priorities:

1. **Beautiful without JavaScript**
2. **Fast on ordinary phones and laptops**
3. **Modern WebGPU/WGSL enhancement where it actually adds value**
4. **True HDR hero output on Chromium + HDR displays**, with clean SDR/CSS fallbacks everywhere else

The page renders as complete HTML/CSS first. The hero shader is lazy-loaded after the first paint and is skipped for reduced-motion, data-saver, unsupported, or constrained environments.

## Stack

- Astro 7 static output
- TypeScript
- Native CSS, cross-document View Transitions, and optional scroll-driven animation
- vgpu 0.3.1 + WGSL for one isolated fullscreen hero
- Extended-range HDR canvas (`rgba16float` + `display-p3` + `toneMapping: extended`), capability-gated
- No React, Three.js, Tailwind, GSAP, remote fonts, or runtime CMS

## Start

```bash
corepack enable
pnpm install
pnpm dev
```

Node 22.12 or newer is required.

## Validate

```bash
pnpm validate
```

This runs Astro diagnostics, WGSL validation, a production build, and bundle-budget checks.

For a real GPU environment check:

```bash
pnpm gpu:doctor
```

## Edit first

- Personal details: `src/data/site.ts`
- Portfolio entries: `src/data/projects.ts`
- Hero copy/layout: `src/components/Hero.astro`
- Visual design: `src/styles/global.css`
- Shader: `src/shaders/hero.wgsl`

## Documentation

- `docs/PROJECT_SPEC.md` — product scope and acceptance criteria
- `docs/TECHNICAL_NOTES.md` — architecture, performance budgets, fallback matrix, HDR boundary
- `docs/SHADER_PORTING.md` — FragCoord-to-WGSL workflow and licensing rules

## Status

This is the live public portfolio for [lotgood](https://github.com/lotgood): a single AethelDesk case study, the HDR WebGPU hero, and the performance guardrails that keep it from becoming a heavy graphics demo.
