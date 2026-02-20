/**
 * Test helpers for bot route integration tests.
 * Provides a minimal Express app with mocked middleware.
 */

import express, { Router, Request, Response, NextFunction } from 'express';

/**
 * Build a minimal Express app that wires up the given router
 * with faked auth / company middleware.
 *
 * @param router  The router under test
 * @param overrides  Optional overrides for req.auth / req.userContext
 */
export function buildApp(
  router: Router,
  overrides: {
    companyCountry?: string;
    companyId?: string;
    userId?: string;
  } = {},
) {
  const app = express();
  app.use(express.json());

  // Inject fake auth + userContext (replaces botAuth + requireLinked)
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = {
      type: 'bot',
      companyId: overrides.companyId ?? 'comp1',
      userId: overrides.userId ?? 'user1',
      companyCountry: overrides.companyCountry ?? 'BR',
    };
    r.userContext = {
      userId: overrides.userId ?? 'user1',
      userName: 'Test User',
      companyId: overrides.companyId ?? 'comp1',
      companyName: 'Test Co',
      role: 'admin',
      permissions: ['read:all', 'write:all', 'delete:all'],
    };
    next();
  });

  app.use('/', router);
  return app;
}
