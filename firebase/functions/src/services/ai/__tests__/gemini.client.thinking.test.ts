jest.mock('firebase-admin', () => ({
  app: () => ({ options: { projectId: 'demo' } }),
  credential: { applicationDefault: () => ({ getAccessToken: async () => ({ access_token: 'token' }) }) },
}));

import { VertexGeminiClient } from '../gemini.client';

const request = { systemPrompt: 's', userText: 'u', media: [], responseSchema: { type: 'object' } };

function mockFetch() {
  const fetchMock = jest.fn().mockResolvedValue({
    ok: true,
    json: async () => ({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
  });
  global.fetch = fetchMock as unknown as typeof fetch;
  return fetchMock;
}

function sentConfig(fetchMock: jest.Mock): Record<string, unknown> {
  return JSON.parse(fetchMock.mock.calls[0][1].body).generationConfig;
}

describe('VertexGeminiClient thinkingLevel', () => {
  it('sends thinkingConfig only when a level is given', async () => {
    const fetchMock = mockFetch();
    await new VertexGeminiClient('gemini-3.8-flash', 'global', 'low').generateJson(request);
    expect(sentConfig(fetchMock).thinkingConfig).toEqual({ thinkingLevel: 'low' });
    expect(fetchMock.mock.calls[0][0]).toContain('https://aiplatform.googleapis.com/v1/projects/demo/locations/global/');
  });

  it('leaves the request unchanged without a level', async () => {
    const fetchMock = mockFetch();
    await new VertexGeminiClient('gemini-2.5-flash', 'southamerica-east1').generateJson(request);
    expect(sentConfig(fetchMock)).not.toHaveProperty('thinkingConfig');
  });
});

describe('VertexGeminiClient usage', () => {
  it('reports prompt tokens and output plus thinking tokens', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: '{}' }] } }],
        usageMetadata: { promptTokenCount: 1700, candidatesTokenCount: 90, thoughtsTokenCount: 80 },
        modelVersion: 'gemini-3.8-flash',
      }),
    }) as unknown as typeof fetch;
    const onUsage = jest.fn();

    await new VertexGeminiClient('gemini-3.8-flash', 'global', 'low').generateJson({ ...request, onUsage });

    expect(onUsage).toHaveBeenCalledWith({ inputTokens: 1700, outputTokens: 170, model: 'gemini-3.8-flash' });
  });
});
