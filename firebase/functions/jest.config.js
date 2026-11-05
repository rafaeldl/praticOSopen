module.exports = {
  // Transpile only: type checking the tests took ~6x longer (CI went past 8 min).
  // Types are checked by `npm run typecheck` (tsconfig.test.json) instead.
  transform: { '^.+\\.ts$': ['ts-jest', { isolatedModules: true }] },
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  collectCoverageFrom: ['src/**/*.ts', '!src/**/*.d.ts'],
  // Cada worker do ts-jest carrega o compilador inteiro (~1 GB). Sem limite, o Jest
  // abre ncpu-1 workers e várias execuções em worktrees paralelas esgotam a memória.
  maxWorkers: 2,
  workerIdleMemoryLimit: '512MB',
};
