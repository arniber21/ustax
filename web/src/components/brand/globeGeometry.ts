/**
 * Dot-matrix globe with a US flag wrapped on it. Pure and deterministic: the same options always give the same dots,
 * so the artwork is testable and never flickers between renders.
 *
 * Geometry: dots on a latitude/longitude grid (so flag stripes line up with dot rows), orthographic projection,
 * slightly tilted and turned. The whole sphere is the flag: 13 stripes run pole to pole (7 dot rows each) and the navy
 * canton with its stars covers part of the northern half. The number of dots per row shrinks with cos(latitude) to keep
 * the spacing even.
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
const ROWS_PER_STRIPE = 7;
/** canton: the first 7 stripes from the north pole; its longitude extent on the sphere */
const CANTON_STRIPES = 7;
const CANTON_LON_START = -74;
const CANTON_LON_WIDTH = 86;

export function globeDots(opts: GlobeOptions = {}): Dot[] {
  const size = opts.size ?? 1000;
  // the flag wraps the whole sphere: 13 stripes pole to pole, 6 dot rows per stripe
  const step = opts.step ?? 180 / (STRIPES * ROWS_PER_STRIPE);
  const tilt = (opts.tilt ?? 12) * DEG;
  const yaw = (opts.yaw ?? -14) * DEG;
  const R = size * 0.44;
  const c = size / 2;
  const stripeDeg = 180 / STRIPES;
  const dots: Dot[] = [];

  const rows = Math.round(180 / step);
  for (let j = 0; j < rows; j++) {
    const lat = 90 - (j + 0.5) * step; // north to south
    const count = Math.max(8, Math.round((360 * Math.cos(lat * DEG)) / step));
    const lonStep = 360 / count;
    const stripe = Math.min(STRIPES - 1, Math.floor((90 - lat) / stripeDeg));
    for (let i = 0; i < count; i++) {
      const lon = -180 + (i + (j & 1 ? 0.5 : 0)) * lonStep;

      let kind: DotKind = stripe % 2 === 0 ? 'red' : 'white';
      const inCantonLon = lon >= CANTON_LON_START && lon < CANTON_LON_START + CANTON_LON_WIDTH;
      if (stripe < CANTON_STRIPES && inCantonLon) {
        // stars: every other row, every other 2*step of longitude
        const cell = Math.floor((lon - CANTON_LON_START) / (2 * step));
        kind = j % 2 === 0 && cell % 2 === 0 ? 'star' : 'navy';
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
        dots.push({
          x: round(px),
          y: round(py),
          r: round(Math.max(0.55, 2.35 * (0.35 + 0.65 * falloff))),
          o: round(0.95 * (0.18 + 0.82 * falloff)),
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
  navy: '#102a66',
  star: '#9db4e6',
  white: '#aab6cc',
  base: '#14306b',
};
