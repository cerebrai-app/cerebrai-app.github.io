// @ts-check
import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import astro from 'eslint-plugin-astro';
import vue from 'eslint-plugin-vue';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig(
  globalIgnores(['dist/', '.astro/', 'node_modules/', 'screenshots/']),

  js.configs.recommended,
  tseslint.configs.strict,
  tseslint.configs.stylistic,

  // Astro components, including accessibility checks on their markup.
  astro.configs['flat/recommended'],
  astro.configs['flat/jsx-a11y-strict'],

  // Vue single-file components, with TypeScript inside <script lang="ts">.
  vue.configs['flat/recommended'],
  {
    files: ['**/*.vue'],
    languageOptions: {
      globals: globals.browser,
      parserOptions: { parser: tseslint.parser },
    },
    rules: {
      'vue/block-lang': ['error', { script: { lang: 'ts' } }],
      'vue/component-api-style': ['error', ['script-setup']],
      'vue/define-macros-order': 'error',
      'vue/no-unused-refs': 'error',
      'vue/no-useless-v-bind': 'error',
      'vue/prefer-true-attribute-shorthand': 'error',
    },
  },

  // Config files run in Node.
  {
    files: ['*.config.{js,mjs,ts}', 'scripts/**'],
    languageOptions: { globals: globals.node },
  },

  {
    rules: {
      eqeqeq: ['error', 'always'],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      '@typescript-eslint/consistent-type-imports': 'error',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
    },
  },

  // Must stay last: turns off rules that would fight Prettier's formatting.
  prettier,
);
