# Project Specification

## Product statement

A compact personal portfolio that feels premium immediately, remains readable and useful with every enhancement disabled, and uses one procedural WebGPU hero as a technical signature rather than as the product itself.

## Experience principles

1. **Content wins.** Name, selected work, role, and contact path are available in the first HTML response.
2. **One memorable effect.** GPU work is limited to the opening hero until a later feature proves its value.
3. **Quiet interaction.** Pointer and scroll influence the visual slightly; they never become required controls.
4. **Graceful degradation.** No WebGPU, reduced motion, data saving, tab backgrounding, and low capability all remain first-class states.
5. **No dependency theatre.** Prefer native browser features and delete libraries that duplicate them.

## P0 scope

- Single-page home with hero, selected projects, profile statement, and contact CTA
- Static project detail pages generated from one typed data file
- Native cross-document View Transitions where supported
- CSS gradient fallback that is visually complete before the GPU starts
- Lazy WebGPU hero with pointer/scroll response and conservative quality profiles
- Semantic structure, keyboard focus, skip navigation, and reduced-motion behavior
- Build, type, shader, and bundle-budget validation

## Non-goals for P0

- CMS, database, server rendering, authentication, analytics, or contact backend
- Three-dimensional scene graph
- Multi-pass bloom, volumetric clouds, FFT ocean, or game-like controls
- Background video in the critical path
- Guaranteed HDR presentation
- Runtime framework islands

## Content model

Keep public content in two files:

- `src/data/site.ts`: identity, short bio, contact, and external links
- `src/data/projects.ts`: card and detail-page content

Do not place project copy directly into components unless it is structural UI text.

## Design direction

- Dark editorial base, restrained iridescent light, very large typography
- System fonts only for P0
- Strong whitespace, fine rules, rounded but not pill-heavy surfaces
- GPU visual supports the text rather than competing with it
- Project cards should remain attractive without screenshots

## P0 acceptance criteria

- The complete home page is readable with JavaScript disabled.
- WebGPU code is not part of the initial static HTML/CSS path and is loaded dynamically.
- Unsupported or opted-out clients never see a broken canvas or error overlay.
- Rendering stops when the hero is offscreen or the document is hidden.
- `prefers-reduced-motion: reduce` disables the animated canvas.
- Project pages build statically from the project data file.
- `pnpm validate` passes on a supported development machine.
- Production initial JS and CSS remain within the checked budgets.
- No third-party shader is shipped without a recorded license and attribution decision.
