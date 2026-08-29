# lotgood — WebGPU Portfolio

A static-first personal portfolio scaffold built for three priorities:

1. **Beautiful without JavaScript**
2. **Fast on ordinary phones and laptops**
3. **Modern WebGPU/WGSL enhancement where it actually adds value**

The page renders as complete HTML/CSS first. The hero shader is lazy-loaded after the first paint and is skipped for reduced-motion, data-saver, unsupported, or constrained environments.

## Stack

- Astro 7 static output
- TypeScript
- Native CSS, cross-document View Transitions, and optional scroll-driven animation
- vgpu 0.3.1 + WGSL for one isolated fullscreen hero
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

## Scaffold status

This archive is a **P0 scaffold**, not a finished public portfolio. It contains representative placeholder content, a working visual direction, and the guardrails needed to continue without turning the site into a heavy graphics demo.
