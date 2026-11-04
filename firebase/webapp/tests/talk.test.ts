// Falar no assistente (order.ai.talk, .cancel-talk, .stop-fill, .speech-engine):
// the recorder's limits, cancel and "nothing heard", with a fake microphone.
import { describe, expect, it } from 'vitest'
import { MAX_AUDIO_BYTES, MAX_TALK_MS, SILENCE_MS, TalkStartError, audioType, pickAudioType, startTalk, type TalkDeps } from '@/lib/orders/talk'

class FakeRecorder {
  chunks: Blob[]
  started = false
  stopped = false
  onData: (blob: Blob) => void = () => {}
  onStop: () => void = () => {}
  constructor(chunks: Blob[]) {
    this.chunks = chunks
  }
  start() {
    this.started = true
  }
  stop() {
    this.stopped = true
    for (const chunk of this.chunks) this.onData(chunk)
    this.onStop()
  }
}

function fake(options: { chunks?: Blob[]; fail?: string; supported?: string[] } = {}) {
  let now = 0
  let level = 0
  let tick: () => void = () => {}
  const state = { tracksStopped: 0, meterClosed: false, recorder: null as FakeRecorder | null, type: '' }
  const deps: TalkDeps = {
    getUserMedia: async () => {
      if (options.fail) throw Object.assign(new Error(options.fail), { name: options.fail })
      return { getTracks: () => [{ stop: () => state.tracksStopped++ }] } as unknown as MediaStream
    },
    isTypeSupported: (type) => (options.supported ?? ['audio/webm;codecs=opus', 'audio/webm']).includes(type),
    createRecorder: (_stream, type) => {
      state.type = type
      state.recorder = new FakeRecorder(options.chunks ?? [new Blob(['som'], { type: 'audio/webm' })])
      return state.recorder
    },
    createMeter: () => ({ level: () => level, close: () => (state.meterClosed = true) }),
    now: () => now,
    every: (_ms, fn) => {
      tick = fn
      return () => (tick = () => {})
    },
  }
  return {
    deps,
    state,
    /** Time passes with this sound level. */
    pass(ms: number, sound = 0) {
      level = sound
      now += ms
      tick()
    },
  }
}

describe('tipo do áudio', () => {
  it('escolhe webm, depois ogg, depois mp4', () => {
    expect(pickAudioType((t) => t.startsWith('audio/webm'))).toBe('audio/webm;codecs=opus')
    expect(pickAudioType((t) => t.startsWith('audio/ogg'))).toBe('audio/ogg;codecs=opus')
    expect(pickAudioType((t) => t === 'audio/mp4')).toBe('audio/mp4')
    expect(pickAudioType(() => false)).toBeNull()
  })
  it('manda só o tipo que o servidor aceita, sem o codec', () => {
    expect(audioType('audio/webm;codecs=opus')).toBe('audio/webm')
    expect(audioType('audio/ogg; codecs=opus')).toBe('audio/ogg')
    expect(audioType('audio/mp4;codecs=mp4a.40.2')).toBe('audio/mp4')
    expect(audioType('video/x-matroska')).toBeNull()
  })
})

describe('gravar', () => {
  it('parar e preencher: manda o áudio em base64 e solta o microfone', async () => {
    const f = fake()
    const talk = await startTalk({}, f.deps)
    expect(f.state.recorder?.started).toBe(true)
    f.pass(500, 0.2)
    talk.stop()
    const end = await talk.done
    expect(end).toEqual({ kind: 'audio', audio: { mimeType: 'audio/webm', data: btoa('som') } })
    expect(f.state.tracksStopped).toBe(1)
    expect(f.state.meterClosed).toBe(true)
  })

  it('cancelar: descarta e nada é mandado', async () => {
    const f = fake()
    const talk = await startTalk({}, f.deps)
    f.pass(500, 0.2)
    talk.cancel()
    expect(await talk.done).toEqual({ kind: 'cancelled' })
    expect(f.state.tracksStopped).toBe(1)
    // A stop after cancel changes nothing.
    talk.stop()
    expect(await talk.done).toEqual({ kind: 'cancelled' })
  })

  it('parar sem ter ouvido nada: vazio, nada é mandado', async () => {
    const f = fake()
    const talk = await startTalk({}, f.deps)
    f.pass(3000, 0.001)
    talk.stop()
    expect(await talk.done).toEqual({ kind: 'empty' })
  })

  it('para sozinho depois de 20 s de silêncio e manda o que ouviu', async () => {
    const f = fake()
    const heard: boolean[] = []
    const talk = await startTalk({ onHeard: () => heard.push(true) }, f.deps)
    f.pass(1000, 0.3)
    expect(heard).toEqual([true])
    f.pass(SILENCE_MS - 1000, 0)
    expect(f.state.recorder?.stopped).toBe(false)
    f.pass(1000, 0)
    expect(f.state.recorder?.stopped).toBe(true)
    expect((await talk.done).kind).toBe('audio')
  })

  it('20 s de silêncio sem ter ouvido nada: vazio', async () => {
    const f = fake()
    const talk = await startTalk({}, f.deps)
    f.pass(SILENCE_MS, 0)
    expect(await talk.done).toEqual({ kind: 'empty' })
  })

  it('para sozinho em 5 minutos mesmo com som', async () => {
    const f = fake()
    const talk = await startTalk({}, f.deps)
    for (let t = 0; t < MAX_TALK_MS - 1000; t += 1000) f.pass(1000, 0.3)
    expect(f.state.recorder?.stopped).toBe(false)
    f.pass(1000, 0.3)
    expect(f.state.recorder?.stopped).toBe(true)
    expect((await talk.done).kind).toBe('audio')
  })

  it('áudio maior que o servidor aceita: avisa em vez de mandar', async () => {
    const f = fake({ chunks: [new Blob([new Uint8Array(MAX_AUDIO_BYTES + 1)])] })
    const talk = await startTalk({}, f.deps)
    f.pass(500, 0.3)
    talk.stop()
    expect(await talk.done).toEqual({ kind: 'too-long' })
  })

  it('grava com o tipo suportado e pouca taxa, para caber nos 5 minutos', async () => {
    const f = fake({ supported: ['audio/mp4'] })
    await startTalk({}, f.deps)
    expect(f.state.type).toBe('audio/mp4')
  })
})

describe('não começou', () => {
  it('permissão negada', async () => {
    await expect(startTalk({}, fake({ fail: 'NotAllowedError' }).deps)).rejects.toEqual(new TalkStartError('denied'))
  })
  it('sem microfone', async () => {
    await expect(startTalk({}, fake({ fail: 'NotFoundError' }).deps)).rejects.toEqual(new TalkStartError('no-mic'))
  })
  it('outro erro', async () => {
    await expect(startTalk({}, fake({ fail: 'AbortError' }).deps)).rejects.toEqual(new TalkStartError('failed'))
  })
  it('navegador sem tipo de áudio que o servidor lê', async () => {
    await expect(startTalk({}, fake({ supported: [] }).deps)).rejects.toEqual(new TalkStartError('unsupported'))
  })
})
