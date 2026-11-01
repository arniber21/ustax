import { describe, expect, it } from 'vitest';
import { render } from '@testing-library/react';
import { globeDots } from './globeGeometry';
import { DotGlobe } from './DotGlobe';

describe('globeDots', () => {
  it('is deterministic', () => {
    expect(globeDots({ size: 1000 })).toEqual(globeDots({ size: 1000 }));
  });

  it('wraps the whole sphere in the flag: every near-side dot is a flag dot, far-side dots are faint base dots', () => {
    const dots = globeDots({ size: 1000 });
    const count = (k: string) => dots.filter((d) => d.kind === k).length;
    expect(count('red')).toBeGreaterThan(500);
    expect(count('white')).toBeGreaterThan(500);
    expect(count('navy')).toBeGreaterThan(100);
    expect(count('star')).toBeGreaterThan(30);
    for (const d of dots) if (d.o > 0.17) expect(d.kind).not.toBe('base');
    // stripes cover the sphere: red and white are present in the upper and the lower half
    const mid = 500;
    for (const k of ['red', 'white']) {
      expect(dots.some((d) => d.kind === k && d.y < mid - 100)).toBe(true);
      expect(dots.some((d) => d.kind === k && d.y > mid + 100)).toBe(true);
    }
  });

  it('keeps every dot inside the viewBox with a valid radius and opacity', () => {
    for (const d of globeDots({ size: 1000 })) {
      expect(d.x).toBeGreaterThanOrEqual(0);
      expect(d.x).toBeLessThanOrEqual(1000);
      expect(d.y).toBeGreaterThanOrEqual(0);
      expect(d.y).toBeLessThanOrEqual(1000);
      expect(d.r).toBeGreaterThan(0);
      expect(d.o).toBeGreaterThan(0);
      expect(d.o).toBeLessThanOrEqual(1);
    }
  });

  it('colours only dots on the near side; the far side is faint and uncoloured', () => {
    const dots = globeDots({ size: 1000 });
    for (const d of dots) if (d.kind !== 'base') expect(d.o).toBeGreaterThan(0.1);
  });

  it('turning the globe moves the dots', () => {
    expect(globeDots({ yaw: 0 })).not.toEqual(globeDots({ yaw: 20 }));
  });
});

describe('DotGlobe', () => {
  it('renders a decorative canvas hidden from assistive technology', () => {
    const { container } = render(<DotGlobe />);
    const canvas = container.querySelector('canvas');
    expect(canvas).not.toBeNull();
    expect(canvas?.getAttribute('aria-hidden')).toBe('true');
    expect(canvas?.className).toContain('pointer-events-none');
  });
});
