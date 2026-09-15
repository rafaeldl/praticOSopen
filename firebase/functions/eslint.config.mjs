// @ts-check
// ESLint flat config (ESLint 9+). Migrated from the legacy .eslintrc.json.
import eslint from '@eslint/js';
import { defineConfig, globalIgnores } from 'eslint/config';
import pluginPromise from 'eslint-plugin-promise';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig(
  globalIgnores([
    'lib/', // tsc output
    'widgets/', // separate project, bundled by esbuild
    'src/mcp/widgets/bundle.ts', // generated, minified widget bundle
  ]),

  eslint.configs.recommended,
  tseslint.configs.recommended,
  pluginPromise.configs['flat/recommended'],

  {
    files: ['**/*.ts'],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
    rules: {
      // The base rule doesn't understand TS types; use the TS-aware version.
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      'no-console': 'off',
      'promise/always-return': 'off',
      'promise/catch-or-return': 'off',
      // Code written before lint was enforced has ~40 `any` in src/ (excluding tests).
      // Warn instead of error so lint is useful without a mass refactor; new
      // code should avoid adding more.
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },

  {
    // Tests rely on `any` for mocks and partial fixtures (~240 uses); not worth typing.
    files: ['**/__tests__/**/*.ts', '**/*.test.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
    },
  },
);
