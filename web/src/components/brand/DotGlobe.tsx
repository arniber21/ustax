import { useEffect, useRef } from 'react';
import { globeDots, type DotKind } from './globeGeometry';

/**
 * Decorative dot-matrix globe with a US flag draped on it, drawn on a canvas (about 8,700 dots is too many DOM nodes
 * for SVG). Transparent background, themed for light and dark, and a very slow sway that is switched off when the
 * user prefers reduced motion. It is purely decorative: hidden from assistive technology and never takes pointer events.
 *
 * Usage: put it in a `relative overflow-hidden` container; it fills the container's width and keeps a square shape.
 *   <DotGlobe className="absolute -right-24 -top-16 w-[620px] opacity-90" />
 */

type Palette = Record<DotKind, string>;

const LIGHT: Palette = {
  red: '179 32 46',
  navy: '16 42 102',
  star: '127 155 224',
  white: '170 182 204',
  base: '20 48 107',
};

const DARK: Palette = {
  red: '229 81 95',
  navy: '111 143 232',
  star: '199 214 255',
  white: '182 194 218',
  base: '157 180 229',
};

function isDark(): boolean {
  return typeof document !== 'undefined' && document.documentElement.classList.contains('dark');
}

export interface DotGlobeProps {
  className?: string;
  /** degrees of yaw the globe sways either side of its resting position (0 disables motion) */
  sway?: number;
}

export function DotGlobe({ className, sway = 5 }: DotGlobeProps) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return; // jsdom / very old browsers: leave it blank

    const reduceMotion =
      typeof window.matchMedia === 'function' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const SIZE = 1000;
    let raf = 0;
    let last = 0;
    let t0 = 0;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const cssW = canvas.clientWidth || 600;
      canvas.width = Math.round(cssW * dpr);
      canvas.height = Math.round(cssW * dpr);
    };

    const draw = (yawOffset: number) => {
      const pal = isDark() ? DARK : LIGHT;
      const scale = canvas.width / SIZE;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const d of globeDots({ size: SIZE, yaw: -14 + yawOffset })) {
        ctx.fillStyle = `rgb(${pal[d.kind]} / ${d.o})`;
        ctx.beginPath();
        ctx.arc(d.x * scale, d.y * scale, d.r * scale, 0, Math.PI * 2);
        ctx.fill();
      }
    };

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame);
      if (now - last < 66) return; // ~15 fps is plenty for a slow drift
      last = now;
      if (!t0) t0 = now;
      const phase = ((now - t0) / 1000 / 28) * Math.PI * 2; // one sway every 28 s
      draw(Math.sin(phase) * sway);
    };

    resize();
    draw(0);
    if (!reduceMotion && sway > 0) raf = requestAnimationFrame(frame);

    const onResize = () => {
      resize();
      draw(0);
    };
    window.addEventListener('resize', onResize);
    // redraw when the theme class changes
    const mo = new MutationObserver(() => draw(0));
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('resize', onResize);
      mo.disconnect();
    };
  }, [sway]);

  return (
    <canvas
      ref={ref}
      aria-hidden="true"
      className={`pointer-events-none aspect-square select-none ${className ?? ''}`}
      style={{ width: '100%' }}
    />
  );
}
