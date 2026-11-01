import '@testing-library/jest-dom/vitest';
import { afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';

afterEach(() => cleanup());

// jsdom lacks a few DOM APIs that Radix Select and cmdk call. No-op stand-ins are enough for tests.
const proto = window.HTMLElement.prototype as unknown as Record<string, unknown>;
proto.hasPointerCapture ??= () => false;
proto.releasePointerCapture ??= () => undefined;
proto.scrollIntoView ??= () => undefined;
window.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
} as unknown as typeof ResizeObserver;
