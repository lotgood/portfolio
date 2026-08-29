import { defineConfig } from 'astro/config';
import wgslVitePlugin from '@vgpu/wgsl/loader-vite';

const site = process.env.SITE_URL;
const base = process.env.BASE_PATH;

export default defineConfig({
  ...(site ? { site } : {}),
  ...(base ? { base } : {}),
  output: 'static',
  compressHTML: true,
  devToolbar: {
    enabled: false
  },
  vite: {
    plugins: [wgslVitePlugin({ minify: true })]
  }
});
