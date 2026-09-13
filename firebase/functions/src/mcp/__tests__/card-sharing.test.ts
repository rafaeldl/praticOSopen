import { cardLocale, shareData } from '../../../widgets/src/card-locale';

describe('order card sharing', () => {
  it('does not offer sharing when there is no customer link', () => {
    expect(shareData({ number: 186 }, 'pt-BR')).toBeNull();
  });
  it('encodes the full draft without selecting a recipient or losing link parameters', () => {
    const link = 'https://example.com/q/demo?a=1&b=2';
    const data = shareData({ number: 186, total: 350, shareUrl: link,
      devices: [{ name: 'Revisão & lavagem', serial: 'ABC1234' }] }, 'pt-BR');
    expect(data?.url).toBe(link);
    expect(data?.text).toContain('Revisão & lavagem');
    expect(data?.text).toContain('OS #186');
    expect(data).not.toHaveProperty('phone');
  });
  it.each(['pt-BR', 'en-US', 'es-ES'])('localizes labels and the draft in %s', locale => {
    const { labels } = cardLocale(locale);
    const data = shareData({ number: 12, total: 42, shareUrl: 'https://example.com/q/demo' }, locale);
    expect(data?.text).toContain(labels.follow);
  });
  it('falls back to Portuguese for unsupported locales', () => {
    expect(cardLocale('ja-JP').locale).toBe('pt-BR');
  });
});
