type ConnectionHint = {
  saveData?: boolean;
};

type NavigatorHints = Navigator & {
  connection?: ConnectionHint;
};

type IdleWindow = Window & {
  requestIdleCallback?: (
    callback: IdleRequestCallback,
    options?: IdleRequestOptions
  ) => number;
};

/**
 * Boots every GPU surface on the page: the hero (when the page has one) and the
 * document-level ambient field. Runs from the layout so project pages get the
 * ambient field too. Everything stays static-first: the page is complete before
 * this runs, and any opt-out or failure leaves the CSS presentation in place.
 */
export function bootVisuals() {
  const heroRoot = document.querySelector<HTMLElement>('[data-hero]');
  const heroCanvas = document.querySelector<HTMLCanvasElement>('[data-hero-canvas]');
  const ambientCanvas = document.querySelector<HTMLCanvasElement>('[data-ambient-canvas]');
  const status = document.querySelector<HTMLElement>('[data-gpu-status]');
  const ambientRoot = ambientCanvas?.closest<HTMLElement>('[data-ambient]') ?? null;

  if (!heroCanvas && !ambientCanvas) return;

  const setStatus = (text: string) => {
    if (status) status.textContent = text;
  };
  const setState = (state: string) => {
    if (heroRoot) heroRoot.dataset.renderState = state;
    if (ambientRoot) ambientRoot.dataset.renderState = state;
  };

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveData = (navigator as NavigatorHints).connection?.saveData === true;

  if (reducedMotion) {
    setState('reduced-motion');
    setStatus('Reduced motion · static');
    return;
  }

  if (saveData) {
    setState('data-saver');
    setStatus('Data saver · static');
    return;
  }

  if (!('gpu' in navigator)) {
    setState('unsupported');
    setStatus('CSS fallback');
    return;
  }

  let disposed = false;
  let starting = false;
  let disposeRenderer: (() => void) | undefined;

  const start = async () => {
    if (disposed || starting || disposeRenderer) return;

    starting = true;
    setState('loading');
    setStatus('Starting WebGPU');

    try {
      const { mountVisuals } = await import('./visuals-runtime');
      const renderer = await mountVisuals({
        ...(heroRoot && heroCanvas ? { hero: { canvas: heroCanvas, root: heroRoot } } : {}),
        ...(ambientCanvas ? { ambient: { canvas: ambientCanvas } } : {})
      });

      if (disposed) {
        renderer.dispose();
        return;
      }

      disposeRenderer = renderer.dispose;
      setState('ready');
      setStatus(`WebGPU · ${renderer.profile}`);

      if (import.meta.env.DEV && new URLSearchParams(location.search).has('hdrcheck')) {
        // Dev-only XDR acceptance aid: a reference-white (#FFFFFF) swatch to compare
        // against highlights. Stripped from production builds by the DEV guard.
        const swatch = document.createElement('div');
        swatch.style.cssText =
          'position:fixed;right:16px;bottom:16px;z-index:99;width:160px;height:90px;' +
          'background:#fff;color:#000;font:11px/1.4 monospace;display:flex;' +
          'align-items:center;justify-content:center;text-align:center;';
        swatch.textContent = 'reference white #FFFFFF — HDR highlights should look brighter';
        document.body.append(swatch);
      }
    } catch (error) {
      console.warn('WebGPU unavailable; retaining CSS presentation.', error);
      setState('failed');
      setStatus('CSS fallback');
    } finally {
      starting = false;
    }
  };

  const scheduleStart = () => {
    const idleWindow = window as IdleWindow;
    if (idleWindow.requestIdleCallback) {
      idleWindow.requestIdleCallback(() => void start(), { timeout: 1000 });
    } else {
      window.setTimeout(() => void start(), 160);
    }
  };

  window.addEventListener('pagehide', () => {
    disposed = true;
    disposeRenderer?.();
    disposeRenderer = undefined;
  });

  window.addEventListener('pageshow', (event) => {
    if (!event.persisted) return;

    disposed = false;
    setState('fallback');
    setStatus('Static first');
    scheduleStart();
  });

  scheduleStart();
}
