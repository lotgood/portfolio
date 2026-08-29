import { defineConfig } from 'astro/config';
import wgslVitePlugin from '@vgpu/wgsl/loader-vite';

const site = process.env.SITE_URL;

export default defineConfig({
  ...(site ? { site } : {}),
  output: 'static',
  compressHTML: true,
  devToolbar: {
    enabled: false
  },
  vite: {
    plugins: [wgslVitePlugin({ minify: true })]
  }
});
