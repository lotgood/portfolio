export type ProjectImage = {
  src: string;
  alt: string;
  caption?: string;
};

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
  liveUrl?: string;
  images?: readonly ProjectImage[];
  accent: string;
  accentAlt: string;
};

export const projects: readonly Project[] = [
  {
    slug: 'aetheldesk',
    index: '01',
    title: 'AethelDesk',
    category: 'Realtime web · shared focus',
    year: '2026',
    summary:
      'A shared celestial focus room for synchronized 50-minute focus and 10-minute recovery sessions — one PIN-protected room that keeps the timer, sky, and completion ritual in sync across devices.',
    statement:
      'A calm product built on strict engineering: deterministic timers, restart-tolerant state, and a completion reward that never replays.',
    details: [
      'The backend is FastAPI with Redis as the single source of room truth: Pub/Sub fans full-state snapshots out to every worker, and a lease-fenced scheduler guarantees a running focus or break keeps advancing through browser disconnects without ever double-decrementing.',
      'The frontend is Vite with vanilla ES modules and one shared Three.js renderer. Three fully procedural environments — a moonlit coast, a city after dark, and an alpine forest — follow the real time of day while the shared controls stay consistent.',
      'Every normal completion lights one node of the code-only Aethel Astrarium and flows into the same fixed ten-minute recovery ritual. The reveal is monotonic: it persists across scene changes and reconnects, and never replays from a restored snapshot.',
      'Rooms are PIN-protected with opaque session tokens; plaintext PINs are never stored. The quality bar is enforced by gates: ruff, pyright, pytest, Playwright browser e2e, and frontend unit tests for the atmosphere, scene manager, storage, and ritual logic.'
    ],
    responsibilities: [
      'Product & systems design',
      'Full-stack implementation',
      'Verification gates'
    ],
    tags: ['FastAPI', 'Redis', 'WebSockets', 'Three.js', 'Vite'],
    liveUrl: 'https://aetheldesk.lotgood.chatgpt.site/',
    images: [
      {
        src: '/assets/projects/aetheldesk/hero-coast-sunset.jpg',
        alt: 'AethelDesk shared focus room overlooking a calm coast at sunset with the completed Aethel Astrarium',
        caption: 'The shared room at sunset, with the Aethel Astrarium complete.'
      },
      {
        src: '/assets/projects/aetheldesk/rest-ritual.jpg',
        alt: 'A 50-minute completion beginning a synchronized 10-minute break with all four Astrarium nodes illuminated',
        caption: 'A completed focus block starting the synchronized recovery ritual.'
      },
      {
        src: '/assets/projects/aetheldesk/city-night.jpg',
        alt: 'Night city environment with lit windows and synchronized focus controls',
        caption: 'The same room, moved to the city after dark.'
      }
    ],
    accent: '#7aa7d8',
    accentAlt: '#e8c07b'
  }
];
