import { applyHostTheme, mergeHostContext, StyleTarget } from '../../../widgets/src/host-theme';

function fakeStyle(): StyleTarget & { props: Map<string, string> } {
  const props = new Map<string, string>();
  return {
    props,
    setProperty: (name, value) => {
      props.set(name, value);
    },
    removeProperty: (name) => {
      const old = props.get(name) ?? '';
      props.delete(name);
      return old;
    },
  };
}

describe('host-theme: mergeHostContext', () => {
  it('mescla a atualizacao parcial sobre o contexto atual', () => {
    const current = { theme: 'light' as const, styles: { variables: { '--color-text-primary': '#000' } } };

    expect(mergeHostContext(current, { theme: 'dark' })).toEqual({
      theme: 'dark',
      styles: { variables: { '--color-text-primary': '#000' } },
    });
  });

  it('aceita contexto ausente dos dois lados', () => {
    expect(mergeHostContext(undefined, null)).toEqual({});
  });
});

describe('host-theme: applyHostTheme', () => {
  it('aplica o tema do host em color-scheme e as variaveis CSS', () => {
    const style = fakeStyle();

    const applied = applyHostTheme(style, {
      theme: 'dark',
      styles: { variables: { '--color-text-primary': 'light-dark(#171717, #fafafa)', '--font-sans': 'X, sans-serif' } },
    });

    expect(style.props.get('color-scheme')).toBe('dark');
    expect(style.props.get('--color-text-primary')).toBe('light-dark(#171717, #fafafa)');
    expect(style.props.get('--font-sans')).toBe('X, sans-serif');
    expect(applied.sort()).toEqual(['--color-text-primary', '--font-sans']);
  });

  it('sem tema, remove color-scheme para valer o "light dark" da folha de estilo', () => {
    const style = fakeStyle();
    style.setProperty('color-scheme', 'dark');

    applyHostTheme(style, {});

    expect(style.props.has('color-scheme')).toBe(false);
  });

  it('ignora chaves que nao sao variaveis CSS e valores vazios ou nao-string', () => {
    const style = fakeStyle();

    const applied = applyHostTheme(style, {
      styles: { variables: { color: 'red', '--color-text-danger': '', '--ok': 'blue', '--bad': 42 as unknown as string } },
    });

    expect([...style.props.keys()]).toEqual(['--ok']);
    expect(applied).toEqual(['--ok']);
  });

  it('remove a variavel que o host deixou de mandar, para voltar ao fallback', () => {
    const style = fakeStyle();
    const first = applyHostTheme(style, { styles: { variables: { '--a': '1', '--b': '2' } } });

    applyHostTheme(style, { styles: { variables: { '--b': '3' } } }, first);

    expect(style.props.has('--a')).toBe(false);
    expect(style.props.get('--b')).toBe('3');
  });
});
