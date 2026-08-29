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

export function bootHero() {
  const root = document.querySelector<HTMLElement>('[data-hero]');
  const canvas = document.querySelector<HTMLCanvasElement>('[data-hero-canvas]');
  const status = document.querySelector<HTMLElement>('[data-gpu-status]');

  if (!root || !canvas) return;

  const setStatus = (text: string) => {
    if (status) status.textContent = text;
  };

  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const saveData = (navigator as NavigatorHints).connection?.saveData === true;

  if (reducedMotion) {
    root.dataset.renderState = 'reduced-motion';
    setStatus('Reduced motion · static');
    return;
  }

  if (saveData) {
    root.dataset.renderState = 'data-saver';
    setStatus('Data saver · static');
    return;
  }

  if (!('gpu' in navigator)) {
    root.dataset.renderState = 'unsupported';
    setStatus('CSS fallback');
    return;
  }

  let disposed = false;
  let starting = false;
  let disposeRenderer: (() => void) | undefined;

  const start = async () => {
    if (disposed || starting || disposeRenderer) return;

    starting = true;
    root.dataset.renderState = 'loading';
    setStatus('Starting WebGPU');

    try {
      const { mountHero } = await import('./hero-runtime');
      const renderer = await mountHero(canvas, root);

      if (disposed) {
        renderer.dispose();
        return;
      }

      disposeRenderer = renderer.dispose;
      root.dataset.renderState = 'ready';
      setStatus(`WebGPU · ${renderer.profile}`);

      if (import.meta.env.DEV && new URLSearchParams(location.search).has('hdrcheck')) {
        // Dev-only XDR acceptance aid: a reference-white (#FFFFFF) swatch to compare
        // against hero highlights. Stripped from production builds by the DEV guard.
        const swatch = document.createElement('div');
        swatch.style.cssText =
          'position:fixed;right:16px;bottom:16px;z-index:99;width:160px;height:90px;' +
          'background:#fff;color:#000;font:11px/1.4 monospace;display:flex;' +
          'align-items:center;justify-content:center;text-align:center;';
        swatch.textContent = 'reference white #FFFFFF — HDR highlights should look brighter';
        document.body.append(swatch);
      }
    } catch (error) {
      console.warn('WebGPU hero unavailable; retaining CSS fallback.', error);
      root.dataset.renderState = 'failed';
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
    root.dataset.renderState = 'fallback';
    setStatus('Static first');
    scheduleStart();
  });

  scheduleStart();
}
