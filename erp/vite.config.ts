import { readFileSync, existsSync } from 'node:fs';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The Supabase address and public (anon) key: the same as the app's, read
// from app/.env (git-ignored; written from the APP_ENV secret in CI).
function appEnv(): Record<string, string> {
  const file = new URL('../app/.env', import.meta.url);
  if (!existsSync(file)) return {};
  const out: Record<string, string> = {};
  for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return out;
}

const env = { ...appEnv(), ...process.env };

export default defineConfig({
  // Relative paths: served from /godoctor/hq/ on GitHub Pages.
  base: './',
  plugins: [react()],
  define: {
    __SUPABASE_URL__: JSON.stringify(env.SUPABASE_URL ?? ''),
    __SUPABASE_ANON_KEY__: JSON.stringify(env.SUPABASE_ANON_KEY ?? ''),
  },
  build: { outDir: 'dist', sourcemap: false, chunkSizeWarningLimit: 900 },
});
