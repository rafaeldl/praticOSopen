import { LlmProviderClient, LlmRequest, LlmRouter, defaultProvider } from '../llm.client';

function fake(name: string, reads: (mime: string) => boolean = () => true): LlmProviderClient & { generateJson: jest.Mock } {
  return { supportsMedia: reads, generateJson: jest.fn().mockResolvedValue(`{"from":"${name}"}`) };
}

const base: LlmRequest = { systemPrompt: 's', userText: 'u', media: [], responseSchema: {} };

describe('LlmRouter', () => {
  it('uses the default provider when the request names none', async () => {
    const gemini = fake('gemini');
    const claude = fake('claude');
    const router = new LlmRouter({ gemini: () => gemini, claude: () => claude }, 'gemini');
    expect(await router.generateJson(base)).toBe('{"from":"gemini"}');
    expect(claude.generateJson).not.toHaveBeenCalled();
  });

  it('uses the provider the company chose', async () => {
    const claude = fake('claude');
    const router = new LlmRouter({ gemini: () => fake('gemini'), claude: () => claude }, 'gemini');
    expect(await router.generateJson({ ...base, provider: 'claude' })).toBe('{"from":"claude"}');
  });

  it('hands media the provider cannot read to the default provider', () => {
    const router = new LlmRouter(
      { gemini: () => fake('gemini'), claude: () => fake('claude', (m) => m.startsWith('image/')) },
      'gemini',
    );
    const photo = { mimeType: 'image/jpeg', data: 'x' };
    const audio = { mimeType: 'audio/mp4', data: 'x' };
    expect(router.resolve({ ...base, provider: 'claude', media: [photo] })).toBe('claude');
    expect(router.resolve({ ...base, provider: 'claude', media: [photo, audio] })).toBe('gemini');
  });

  it('falls back when the chosen provider is not configured', () => {
    const router = new LlmRouter({ gemini: () => fake('gemini') }, 'gemini');
    expect(router.resolve({ ...base, provider: 'claude' })).toBe('gemini');
  });
});

describe('defaultProvider', () => {
  it('reads AI_PROVIDER and ignores unknown values', () => {
    expect(defaultProvider({ AI_PROVIDER: 'claude' })).toBe('claude');
    expect(defaultProvider({ AI_PROVIDER: 'gpt' })).toBe('gemini');
    expect(defaultProvider({})).toBe('gemini');
  });
});
