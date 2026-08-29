import {
  clock,
  effect,
  frameLoop,
  init,
  surface,
  type Frame,
  type FrameLoopHandle
} from 'vgpu';
import heroShader from '../shaders/hero.wgsl';

type NavigatorCapabilities = Navigator & {
  deviceMemory?: number;
};

type QualityProfile = {
  label: 'high' | 'balanced' | 'light';
  dpr: readonly [number, number];
  quality: number;
  fps: number;
};

type Vec2 = [number, number];

function selectProfile(): QualityProfile {
  const hints = navigator as NavigatorCapabilities;
  const memory = hints.deviceMemory ?? 8;
  const cores = navigator.hardwareConcurrency ?? 8;
  const coarsePointer = matchMedia('(pointer: coarse)').matches;
  const narrow = window.innerWidth < 760;

  if (coarsePointer || narrow || memory <= 4 || cores <= 4) {
    return {
      label: 'light',
      dpr: [0.75, 1],
      quality: 0.5,
      fps: 30
    };
  }

  if (memory < 8 || cores < 8) {
    return {
      label: 'balanced',
      dpr: [0.85, 1.25],
      quality: 0.75,
      fps: 60
    };
  }

  return {
    label: 'high',
    dpr: [1, 1.5],
    quality: 1,
    fps: 60
  };
}

export async function mountHero(canvas: HTMLCanvasElement, root: HTMLElement) {
  const profile = selectProfile();
  const gpu = await init();

  try {
    const colorSpace: PredefinedColorSpace = matchMedia('(color-gamut: p3)').matches
      ? 'display-p3'
      : 'srgb';
    const output = surface(gpu, canvas, {
      dpr: profile.dpr,
      colorSpace,
      alphaMode: 'opaque'
    });
    const getAspect = () => output.size[0] / Math.max(output.size[1], 1);
    const getViewport = (): Vec2 => [output.size[0], output.size[1]];

    let pointer: Vec2 = [0.5, 0.46];
    let pointerTarget: Vec2 = [0.5, 0.46];
    let scroll = 0;
    let scrollTarget = 0;
    let adaptiveQuality = profile.quality;
    let frameAverage = 1000 / profile.fps;
    let previousFrameTime = performance.now();
    let lastQualityChange = previousFrameTime;
    let isIntersecting = true;
    let loop: FrameLoopHandle | undefined;

    const shader = effect(gpu, heroShader, {
      set: {
        hero: {
          time: 0,
          aspect: getAspect(),
          scroll: 0,
          quality: adaptiveQuality,
          pointer,
          viewport: getViewport()
        }
      }
    });

    const unsubscribeResize = output.onResize(() => {
      shader.set({
        hero: {
          aspect: getAspect(),
          viewport: getViewport()
        }
      });
    });

    const timer = clock(gpu);

    const render = (frame: Frame) => {
      const now = performance.now();
      const delta = Math.min(now - previousFrameTime, 100);
      previousFrameTime = now;
      frameAverage += (delta - frameAverage) * 0.04;

      pointer = [
        pointer[0] + (pointerTarget[0] - pointer[0]) * 0.055,
        pointer[1] + (pointerTarget[1] - pointer[1]) * 0.055
      ];
      scroll += (scrollTarget - scroll) * 0.05;

      const targetFrame = 1000 / profile.fps;
      if (
        adaptiveQuality > 0.5 &&
        frameAverage > targetFrame * 1.28 &&
        now - lastQualityChange > 2200
      ) {
        adaptiveQuality = Math.max(0.5, adaptiveQuality - 0.25);
        lastQualityChange = now;
      }

      shader.set({
        hero: {
          time: timer.time,
          pointer,
          scroll,
          quality: adaptiveQuality
        }
      });

      frame.pass(output, shader);
    };

    const shouldRender = () =>
      document.visibilityState === 'visible' && isIntersecting;

    const startLoop = () => {
      if (loop || !shouldRender()) return;
      previousFrameTime = performance.now();
      loop = frameLoop(gpu, render, { fps: profile.fps });
    };

    const stopLoop = () => {
      loop?.stop();
      loop = undefined;
    };

    const syncLoop = () => {
      if (shouldRender()) startLoop();
      else stopLoop();
    };

    const onPointerMove = (event: PointerEvent) => {
      const bounds = root.getBoundingClientRect();
      if (bounds.width <= 0 || bounds.height <= 0) return;

      pointerTarget = [
        Math.min(1, Math.max(0, (event.clientX - bounds.left) / bounds.width)),
        Math.min(1, Math.max(0, (event.clientY - bounds.top) / bounds.height))
      ];
    };

    const onPointerLeave = () => {
      pointerTarget = [0.5, 0.46];
    };

    const onScroll = () => {
      const bounds = root.getBoundingClientRect();
      const travel = Math.max(root.offsetHeight, 1);
      scrollTarget = Math.min(1, Math.max(0, -bounds.top / travel));
    };

    const observer = new IntersectionObserver(
      ([entry]) => {
        isIntersecting = entry?.isIntersecting ?? false;
        syncLoop();
      },
      { rootMargin: '160px 0px' }
    );

    root.addEventListener('pointermove', onPointerMove, { passive: true });
    root.addEventListener('pointerleave', onPointerLeave, { passive: true });
    window.addEventListener('scroll', onScroll, { passive: true });
    document.addEventListener('visibilitychange', syncLoop, { passive: true });
    observer.observe(root);
    onScroll();
    startLoop();

    return {
      profile: `${profile.label} · ${colorSpace === 'display-p3' ? 'P3' : 'sRGB'}`,
      dispose() {
        stopLoop();
        observer.disconnect();
        unsubscribeResize();
        root.removeEventListener('pointermove', onPointerMove);
        root.removeEventListener('pointerleave', onPointerLeave);
        window.removeEventListener('scroll', onScroll);
        document.removeEventListener('visibilitychange', syncLoop);
        gpu.dispose();
      }
    };
  } catch (error) {
    gpu.dispose();
    throw error;
  }
}
