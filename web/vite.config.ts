import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// The API contract (schema, fixtures) lives in ../api; allow the dev server to read it.
export default defineConfig({
  plugins: [react()],
  server: { fs: { allow: ['..'] } },
  test: { environment: 'node', include: ['src/**/*.test.ts'] },
});
