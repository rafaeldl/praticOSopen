import type { NextFunction, Request, Response } from 'express';

type BodyParserError = Error & { type?: unknown; status?: unknown; statusCode?: unknown; body?: unknown };

/**
 * body-parser errors (invalid JSON, body too large, ...) carry the raw request
 * body in `err.body`, and JSON.parse messages quote part of it. Webhook and
 * public routes receive tokens and customer data, so for these errors only the
 * type/status/name may reach the log.
 */
function isRequestBodyError(err: BodyParserError): boolean {
  return (typeof err.type === 'string' && typeof (err.status ?? err.statusCode) === 'number')
    || (err instanceof SyntaxError && 'body' in err);
}

/** Express global error handler (mounted last in src/index.ts). */
export function globalErrorHandler(err: Error, _req: Request, res: Response, _next: NextFunction) {
  const bodyError = err as BodyParserError;
  if (isRequestBodyError(bodyError)) {
    console.error('Unhandled error:', {
      type: typeof bodyError.type === 'string' ? bodyError.type : undefined,
      status: bodyError.status ?? bodyError.statusCode,
      name: err.name,
    });
  } else {
    console.error('Unhandled error:', err);
  }

  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: err.message,
      },
    });
  }

  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Invalid or missing authentication',
      },
    });
  }

  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: process.env.NODE_ENV === 'development'
        ? err.message
        : 'An unexpected error occurred',
    },
  });
}
