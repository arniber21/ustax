/**
 * Dot-matrix globe with a US flag wrapped on it. Pure and deterministic: the same options always give the same dots,
 * so the artwork is testable and never flickers between renders.
 *
 * Geometry: dots on a regular latitude/longitude grid (so flag stripes line up with dot rows), orthographic projection,
 * slightly tilted and turned. Between +-FLAG_ROWS the longitude spacing is constant so the flag's columns stay straight;
 * toward the poles the number of dots per row shrinks with cos(latitude) to keep the spacing even.
 * Dots fade and shrink toward the limb (the "dot gradient"). Dots on the far side are drawn very faintly so the
 * globe reads as a transparent sphere.
 */

export type DotKind = 'red' | 'white' | 'navy' | 'star' | 'base';

export interface Dot {
  x: number;
  y: number;
  r: number;
  /** 0..1 opacity before theme colour is applied */
  o: number;
  kind: DotKind;
}

export interface GlobeOptions {
  /** viewBox is `size` x `size`, globe centred */
  size?: number;
  /** grid step in degrees (smaller = more dots) */
  step?: number;
  /** tilt of the axis toward the viewer, degrees */
  tilt?: number;
  /** yaw of the globe, degrees (turns the flag across the face) */
  yaw?: number;
}

const DEG = Math.PI / 180;
const STRIPES = 13;
const ROWS_PER_STRIPE = 2;
/** canton covers the top 7 stripes and 40% of the width (the real flag proportions) */
const CANTON_STRIPES = 7;
const CANTON_W = 0.4;
const FLAG_ASPECT = 1.9;

export function globeDots(opts: GlobeOptions = {}): Dot[] {
  const size = opts.size ?? 1000;
  const step = opts.step ?? 2.2;
  const tilt = (opts.tilt ?? 12) * DEG;
  const yaw = (opts.yaw ?? -14) * DEG;
  const R = size * 0.44;
  const c = size / 2;

  const flagLat = STRIPES * ROWS_PER_STRIPE * step; // degrees of latitude the flag covers
  const flagLon = flagLat * FLAG_ASPECT;
  const halfLat = flagLat / 2;
  const dots: Dot[] = [];

  // rows centred on latitude 0 so the flag is centred: lat = (j + 0.5) * step
  const maxJ = Math.floor(90 / step);
  for (let j = -maxJ; j < maxJ; j++) {
    const lat = (j + 0.5) * step;
    if (Math.abs(lat) >= 90) continue;
    const inFlagBand = Math.abs(lat) <= halfLat + step;
    const count = inFlagBand
      ? Math.round(360 / step)
      : Math.max(6, Math.round((360 * Math.cos(lat * DEG)) / step));
    const lonStep = 360 / count;
    for (let i = 0; i < count; i++) {
      const lon = -180 + (i + (inFlagBand ? 0.5 : (j & 1 ? 0.5 : 0))) * lonStep;

      // flag colour (null outside the flag)
      let kind: DotKind = 'base';
      if (Math.abs(lat) <= halfLat && Math.abs(lon) <= flagLon / 2) {
        const stripe = Math.min(STRIPES - 1, Math.floor((halfLat - lat) / (ROWS_PER_STRIPE * step)));
        const u = (lon + flagLon / 2) / flagLon;
        if (u < CANTON_W && stripe < CANTON_STRIPES) {
          // stars on every other row and column of the canton
          const row = Math.floor((halfLat - lat) / step);
          const col = Math.floor((lon + flagLon / 2) / step);
          kind = row % 2 === 0 && col % 2 === 0 ? 'star' : 'navy';
        } else {
          kind = stripe % 2 === 0 ? 'red' : 'white';
        }
      }

      // sphere point (z towards the viewer), then yaw about the vertical axis and tilt about the horizontal axis
      const la = lat * DEG;
      const lo = lon * DEG;
      const x0 = Math.cos(la) * Math.sin(lo);
      const y0 = Math.sin(la);
      const z0 = Math.cos(la) * Math.cos(lo);
      const xr = x0 * Math.cos(yaw) + z0 * Math.sin(yaw);
      const zr = -x0 * Math.sin(yaw) + z0 * Math.cos(yaw);
      const yt = y0 * Math.cos(tilt) - zr * Math.sin(tilt);
      const zt = y0 * Math.sin(tilt) + zr * Math.cos(tilt);

      const px = c + xr * R;
      const py = c - yt * R;

      if (zt >= 0) {
        const falloff = Math.pow(zt, 0.55); // 1 at the centre of the disc, 0 at the limb
        const baseR = kind === 'base' ? 1.9 : 2.7;
        dots.push({
          x: round(px),
          y: round(py),
          r: round(Math.max(0.55, baseR * (0.35 + 0.65 * falloff))),
          o: round((kind === 'base' ? 0.4 : 0.95) * (0.18 + 0.82 * falloff)),
          kind,
        });
      } else {
        // far side: tiny, faint, uncoloured, so the sphere feels see-through
        const f = Math.pow(-zt, 0.8);
        dots.push({
          x: round(px),
          y: round(py),
          r: round(0.8 + 0.4 * (1 - f)),
          o: round(0.06 + 0.1 * (1 - f)),
          kind: 'base',
        });
      }
    }
  }
  // far side first, then front: low opacity first so bright dots draw on top
  dots.sort((a, b) => a.o - b.o);
  return dots;
}

function round(v: number): number {
  return Math.round(v * 100) / 100;
}

/** Colours for a standalone SVG/preview (the app component themes these with CSS variables instead). */
export const GLOBE_COLORS = {
  red: '#b3202e',
  navy: '#14306b',
  star: '#9db4e6',
  white: '#8493ad',
  base: '#14306b',
};
