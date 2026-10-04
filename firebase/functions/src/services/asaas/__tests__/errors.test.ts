import { AsaasApiError } from '../asaas-client';
import { AsaasServiceError, toHttpError } from '../errors';

describe('toHttpError', () => {
  it('mapeia AsaasServiceError pelo código', () => {
    const result = toHttpError(new AsaasServiceError('INVALID_VALUE', 'Value exceeds balance'), 'x');
    expect(result).toEqual({
      status: 400,
      body: { success: false, error: { code: 'INVALID_VALUE', message: 'Value exceeds balance' } },
    });
    expect(toHttpError(new AsaasServiceError('ASAAS_NOT_ENABLED', 'm'), 'x').status).toBe(403);
    expect(toHttpError(new AsaasServiceError('CHARGE_NOT_FOUND', 'm'), 'x').status).toBe(404);
    expect(toHttpError(new AsaasServiceError('ASAAS_NOT_CONNECTED', 'm'), 'x').status).toBe(409);
  });

  it('mapeia 400 do Asaas com a descrição', () => {
    const error = new AsaasApiError(400, [{ code: 'invalid_cpfCnpj', description: 'CPF inválido' }], '/customers');
    expect(toHttpError(error, 'x')).toEqual({
      status: 400,
      body: { success: false, error: { code: 'ASAAS_VALIDATION_ERROR', message: 'CPF inválido' } },
    });
  });

  it('mapeia 401 do Asaas para chave recusada', () => {
    const result = toHttpError(new AsaasApiError(401, [], '/payments'), 'x');
    expect(result.status).toBe(400);
    expect(result.body.error.code).toBe('ASAAS_INVALID_API_KEY');
    expect(toHttpError(new AsaasApiError(403, [], '/payments'), 'x').status).toBe(400);
    expect(toHttpError(new AsaasServiceError('ASAAS_INVALID_API_KEY', 'm'), 'x').status).toBe(400);
  });

  it.each([
    ['TimeoutError', new DOMException('timed out', 'TimeoutError')],
    ['AbortError', new DOMException('aborted', 'AbortError')],
    ['fetch TypeError', new TypeError('fetch failed')],
  ])('mapeia falha de rede (%s) para 502 ASAAS_UNAVAILABLE', (_n, error) => {
    const result = toHttpError(error, 'x');
    expect(result.status).toBe(502);
    expect(result.body.error.code).toBe('ASAAS_UNAVAILABLE');
  });

  it('TypeError sem relação com fetch continua 500', () => {
    expect(toHttpError(new TypeError('x is not a function'), 'x').status).toBe(500);
  });

  it('mapeia 5xx do Asaas para 502', () => {
    const result = toHttpError(new AsaasApiError(503, [], '/payments'), 'x');
    expect(result.status).toBe(502);
    expect(result.body.error.code).toBe('ASAAS_UNAVAILABLE');
  });

  it('erro desconhecido vira 500 com a mensagem padrão', () => {
    expect(toHttpError(new Error('boom'), 'Failed to create charge')).toEqual({
      status: 500,
      body: { success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to create charge' } },
    });
  });
});
