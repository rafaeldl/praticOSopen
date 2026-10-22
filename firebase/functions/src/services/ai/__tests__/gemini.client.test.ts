import { toGeminiSchema } from '../gemini.client';
import { LLM_RESPONSE_SCHEMA } from '../order-assist.service';

describe('toGeminiSchema', () => {
  it('turns the shared schema into the Gemini responseSchema with add/update/remove operations', () => {
    expect(toGeminiSchema(LLM_RESPONSE_SCHEMA)).toEqual({
      type: 'OBJECT',
      properties: {
        transcript: { type: 'STRING' },
        customer: { type: 'OBJECT', properties: { name: { type: 'STRING' }, phone: { type: 'STRING' } } },
        device: {
          type: 'OBJECT',
          properties: { name: { type: 'STRING' }, serial: { type: 'STRING' }, manufacturer: { type: 'STRING' } },
        },
        operations: {
          type: 'ARRAY',
          items: {
            type: 'OBJECT',
            properties: {
              action: { type: 'STRING', enum: ['add', 'update', 'remove'] },
              line: { type: 'STRING', nullable: true },
              candidates: { type: 'ARRAY', items: { type: 'STRING' } },
              kind: { type: 'STRING', enum: ['service', 'product'] },
              name: { type: 'STRING' },
              description: { type: 'STRING' },
              value: { type: 'NUMBER', nullable: true },
              quantity: { type: 'NUMBER', nullable: true },
            },
            required: ['action', 'kind', 'name'],
          },
        },
        notes: { type: 'STRING' },
        dueDate: { type: 'STRING' },
        dueTime: { type: 'STRING' },
      },
      required: ['operations'],
    });
  });
});
