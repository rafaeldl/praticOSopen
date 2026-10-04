import express from 'express';
import request from 'supertest';
import { globalErrorHandler } from '../error-handler.middleware';

const MARKER = 'marker_raw_body_must_not_be_logged';

function buildApp(handlerError?: Error) {
  const app = express();
  app.use(express.json({ limit: '1kb' }));
  app.post('/x', () => {
    throw handlerError ?? new Error('boom');
  });
  app.use(globalErrorHandler);
  return app;
}

describe('globalErrorHandler', () => {
  let errorSpy: jest.SpyInstance;

  beforeEach(() => {
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  afterEach(() => errorSpy.mockRestore());

  // Everything console.error received, including Error message/stack/body.
  const logged = () => errorSpy.mock.calls.flat().map((arg: unknown) => {
    if (arg instanceof Error) {
      const { message, stack } = arg;
      return `${message} ${stack} ${JSON.stringify(arg)} ${String((arg as Error & { body?: unknown }).body)}`;
    }
    return JSON.stringify(arg);
  }).join('\n');

  it('JSON inválido: não loga o corpo bruto nem a mensagem do parser', async () => {
    const res = await request(buildApp())
      .post('/x')
      .set('Content-Type', 'application/json')
      .send(`{"token": "${MARKER}"`);

    expect(errorSpy).toHaveBeenCalled();
    expect(logged()).not.toContain(MARKER);
    expect(errorSpy.mock.calls[0][1]).toEqual({ type: 'entity.parse.failed', status: 400, name: 'SyntaxError' });
    // Response unchanged from before.
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });

  it('corpo grande demais: não loga o corpo', async () => {
    const res = await request(buildApp())
      .post('/x')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ token: MARKER, pad: 'x'.repeat(2048) }));

    expect(logged()).not.toContain(MARKER);
    expect(errorSpy.mock.calls[0][1]).toMatchObject({ type: 'entity.too.large', status: 413 });
    expect(res.status).toBe(500);
  });

  it('SyntaxError com propriedade body fora do body-parser também é redigido', async () => {
    const err = Object.assign(new SyntaxError(`bad ${MARKER}`), { body: MARKER });
    await request(buildApp(err)).post('/x').send({});
    expect(logged()).not.toContain(MARKER);
  });

  it('outros erros mantêm o log e as respostas atuais', async () => {
    const err = new Error('regular failure');
    const res = await request(buildApp(err)).post('/x').send({});
    expect(errorSpy).toHaveBeenCalledWith('Unhandled error:', err);
    expect(res.status).toBe(500);

    const validation = Object.assign(new Error('bad field'), { name: 'ValidationError' });
    const res400 = await request(buildApp(validation)).post('/x').send({});
    expect(res400.status).toBe(400);
    expect(res400.body.error).toEqual({ code: 'VALIDATION_ERROR', message: 'bad field' });

    const unauthorized = Object.assign(new Error('nope'), { name: 'UnauthorizedError' });
    expect((await request(buildApp(unauthorized)).post('/x').send({})).status).toBe(401);
  });
});
