// @ts-check
import { defineConfig } from 'astro/config';
import vue from '@astrojs/vue';

// https://astro.build/config
export default defineConfig({
  // Organization site repo (<org>.github.io), so it is served from the root and needs no `base`.
  site: 'https://cerebrai-app.github.io',
  integrations: [vue()],
});
