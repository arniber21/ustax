import { useEffect, useRef, useState } from 'react';

/** True when the user asked for less motion. Environments without matchMedia count as reduced. */
export function prefersReducedMotion(): boolean {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return true;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/**
 * Eases an integer from its previous value to `target` over `durationMs`.
 * With reduced motion it returns `target` immediately. Always an integer; the final frame is exactly `target`.
 */
export function useCountUp(target: number, durationMs = 900): number {
  const reduced = prefersReducedMotion();
  const [value, setValue] = useState(reduced ? target : 0);
  const from = useRef(reduced ? target : 0);

  useEffect(() => {
    if (prefersReducedMotion()) {
      from.current = target;
      setValue(target);
      return;
    }
    const start = performance.now();
    const origin = from.current;
    let frame = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / durationMs);
      const eased = 1 - Math.pow(1 - t, 3);
      const v = t >= 1 ? target : Math.round(origin + (target - origin) * eased);
      from.current = v;
      setValue(v);
      if (t < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target, durationMs]);

  return reduced ? target : value;
}
