import { toGeminiSchema } from '../gemini.client';
import { LLM_RESPONSE_SCHEMA } from '../order-assist.service';

describe('toGeminiSchema', () => {
  it('turns the shared schema into the Gemini responseSchema used before', () => {
    expect(toGeminiSchema(LLM_RESPONSE_SCHEMA)).toEqual({
      type: 'OBJECT',
      properties: {
        transcript: { type: 'STRING' },
        customer: { type: 'OBJECT', properties: { name: { type: 'STRING' }, phone: { type: 'STRING' } } },
        device: {
          type: 'OBJECT',
          properties: { name: { type: 'STRING' }, serial: { type: 'STRING' }, manufacturer: { type: 'STRING' } },
        },
        items: {
          type: 'ARRAY',
          items: {
            type: 'OBJECT',
            properties: {
              kind: { type: 'STRING', enum: ['service', 'product'] },
              name: { type: 'STRING' },
              value: { type: 'NUMBER', nullable: true },
              quantity: { type: 'NUMBER' },
            },
            required: ['kind', 'name'],
          },
        },
        notes: { type: 'STRING' },
        dueDate: { type: 'STRING' },
        dueTime: { type: 'STRING' },
      },
      required: ['items'],
    });
  });
});
