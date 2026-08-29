export type Project = {
  slug: string;
  index: string;
  title: string;
  category: string;
  year: string;
  summary: string;
  statement: string;
  details: readonly string[];
  responsibilities: readonly string[];
  tags: readonly string[];
  accent: string;
  accentAlt: string;
};

export const projects: readonly Project[] = [
  {
    slug: 'observer-array',
    index: '01',
    title: 'Observer Array',
    category: 'Interactive systems',
    year: '2026',
    summary:
      'An evidence-driven observation game experiment built around uncertainty, progression, and readable state.',
    statement:
      'A project about making complex systems legible without flattening the mystery that makes them interesting.',
    details: [
      'The public case study should explain the player loop, the design constraints, and what changed after testing.',
      'Replace this scaffold copy with concise evidence: one diagram, a few strong screenshots, and measurable outcomes.'
    ],
    responsibilities: ['Product direction', 'Systems design', 'Implementation verification'],
    tags: ['Game design', 'State systems', 'UX'],
    accent: '#7287ff',
    accentAlt: '#c18bff'
  },
  {
    slug: 'farmtory',
    index: '02',
    title: 'Farmtory',
    category: 'Simulation · automation',
    year: '2026',
    summary:
      'A compact farming and automation simulation focused on deterministic behavior and clear player feedback.',
    statement:
      'The interesting work is not the number of systems, but the discipline required to make each system predictable and testable.',
    details: [
      'Use this page to show one loop from input to simulation state to visible feedback.',
      'Prefer a small verified slice over a broad feature list. Explain trade-offs and the validation approach.'
    ],
    responsibilities: ['Simulation design', 'Quality gates', 'Interaction tuning'],
    tags: ['Simulation', 'Automation', 'Determinism'],
    accent: '#6fd7aa',
    accentAlt: '#e8d07b'
  },
  {
    slug: 'gpu-lab',
    index: '03',
    title: 'GPU Lab',
    category: 'WebGPU · procedural graphics',
    year: '2026',
    summary:
      'A small browser graphics laboratory connecting shader authoring, a tiny WebGPU runtime, and static-first delivery.',
    statement:
      'A visual signature can be technically ambitious without making every visitor pay for a graphics demo.',
    details: [
      'Document the FragCoord-to-WGSL workflow, capability fallbacks, and measured bundle cost.',
      'A final case study should compare the CSS-only, WebGPU SDR, and future verified HDR paths.'
    ],
    responsibilities: ['Visual direction', 'WGSL', 'Performance architecture'],
    tags: ['Astro', 'vgpu', 'WGSL'],
    accent: '#76c7ff',
    accentAlt: '#b795ff'
  }
];

export function getProject(slug: string) {
  return projects.find((project) => project.slug === slug);
}
