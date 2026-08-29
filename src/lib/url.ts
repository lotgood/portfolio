const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** Prefixes a root-absolute path with the configured Astro base (no-op at base "/"). */
export function withBase(path: string): string {
  return `${base}${path.startsWith('/') ? path : `/${path}`}`;
}
