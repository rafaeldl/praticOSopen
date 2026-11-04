// Falar no assistente (order.ai.talk, .cancel-talk, .stop-fill, .speech-engine).
// The app hears on the phone (speech_to_text) and sends text; the browser
// records the voice with MediaRecorder and sends the audio itself, which the
// server's model transcribes (POST /v1/app/ai/order-assist {audio}). Loaded only
// when Falar is tapped (dynamic import), so the first download does not grow.
// Like the app's speech_listener.dart: it keeps listening until "Parar e
// preencher", 20 s without sound or 5 min; stopping with nothing heard sends nothing.
import { toBase64 } from './assist-photo'

export const SILENCE_MS = 20_000
export const MAX_TALK_MS = 5 * 60_000
/** The server's limit (MAX_AUDIO_BYTES in order-assist.service.ts). */
export const MAX_AUDIO_BYTES = 3 * 1024 * 1024
/** Voice at 32 kbps: 5 minutes is about 1.2 MB, well under the limit. */
export const AUDIO_BITS = 32_000
/** RMS of the samples (0–1) above which the microphone heard something. */
const SOUND_LEVEL = 0.02
const TICK_MS = 250

const TYPES = ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/ogg', 'audio/mp4']
const SERVER_TYPES = ['audio/webm', 'audio/ogg', 'audio/mp4'] as const
export type AudioType = (typeof SERVER_TYPES)[number]

/** The first type this browser records, in the order webm, ogg, mp4. */
export function pickAudioType(isTypeSupported: (type: string) => boolean): string | null {
  return TYPES.find((type) => isTypeSupported(type)) ?? null
}

/** The recorder's type as the server accepts it, without the codec. */
export function audioType(type: string): AudioType | null {
  const base = (type.split(';')[0] ?? '').trim().toLowerCase()
  return (SERVER_TYPES as readonly string[]).includes(base) ? (base as AudioType) : null
}

export interface RecorderLike {
  onData: (blob: Blob) => void
  onStop: () => void
  start(): void
  stop(): void
}

export interface TalkDeps {
  getUserMedia(): Promise<MediaStream>
  isTypeSupported(type: string): boolean
  createRecorder(stream: MediaStream, type: string): RecorderLike
  /** Sound level now, 0–1. */
  createMeter(stream: MediaStream): { level(): number; close(): void }
  now(): number
  every(ms: number, fn: () => void): () => void
}

export type TalkFailure = 'denied' | 'no-mic' | 'unsupported' | 'failed'
export class TalkStartError extends Error {
  constructor(readonly code: TalkFailure) {
    super(code)
  }
}

export type TalkEnd = { kind: 'audio'; audio: { mimeType: AudioType; data: string } } | { kind: 'empty' } | { kind: 'cancelled' } | { kind: 'too-long' } | { kind: 'failed' }

export interface TalkHandle {
  /** "Parar e preencher". */
  stop(): void
  /** "Cancelar": what was recorded is thrown away. */
  cancel(): void
  done: Promise<TalkEnd>
}

function browserDeps(): TalkDeps {
  return {
    getUserMedia: () => navigator.mediaDevices.getUserMedia({ audio: true }),
    isTypeSupported: (type) => MediaRecorder.isTypeSupported(type),
    createRecorder(stream, type) {
      const recorder = new MediaRecorder(stream, { mimeType: type, audioBitsPerSecond: AUDIO_BITS })
      const like: RecorderLike = {
        onData: () => {},
        onStop: () => {},
        start: () => recorder.start(1000),
        stop: () => {
          if (recorder.state !== 'inactive') recorder.stop()
        },
      }
      recorder.ondataavailable = (event) => like.onData(event.data)
      recorder.onstop = () => like.onStop()
      return like
    },
    createMeter(stream) {
      const context = new AudioContext()
      const analyser = context.createAnalyser()
      // About a third of a second per read, so short sounds between ticks still count.
      analyser.fftSize = 16384
      context.createMediaStreamSource(stream).connect(analyser)
      const samples = new Float32Array(analyser.fftSize)
      return {
        level() {
          analyser.getFloatTimeDomainData(samples)
          let sum = 0
          for (const sample of samples) sum += sample * sample
          return Math.sqrt(sum / samples.length)
        },
        close: () => void context.close().catch(() => {}),
      }
    },
    now: () => Date.now(),
    every(ms, fn) {
      const id = setInterval(fn, ms)
      return () => clearInterval(id)
    },
  }
}

function failureOf(error: unknown): TalkFailure {
  const name = (error as { name?: string } | null)?.name
  if (name === 'NotAllowedError' || name === 'SecurityError' || name === 'PermissionDeniedError') return 'denied'
  if (name === 'NotFoundError' || name === 'DevicesNotFoundError' || name === 'NotReadableError') return 'no-mic'
  return 'failed'
}

/**
 * Asks for the microphone (only now, on Falar) and starts recording. Throws
 * TalkStartError when it cannot start; otherwise `done` says how it ended.
 */
export async function startTalk(options: { onHeard?: () => void } = {}, deps: TalkDeps = browserDeps()): Promise<TalkHandle> {
  const recorderType = pickAudioType(deps.isTypeSupported)
  const type = recorderType && audioType(recorderType)
  if (!recorderType || !type) throw new TalkStartError('unsupported')
  let stream: MediaStream
  try {
    stream = await deps.getUserMedia()
  } catch (error) {
    throw new TalkStartError(failureOf(error))
  }
  const chunks: Blob[] = []
  let meter: { level(): number; close(): void } | null = null
  let recorder: RecorderLike
  try {
    recorder = deps.createRecorder(stream, recorderType)
    meter = deps.createMeter(stream)
  } catch (error) {
    stream.getTracks().forEach((track) => track.stop())
    meter?.close()
    throw new TalkStartError(failureOf(error))
  }
  const startedAt = deps.now()
  let lastSoundAt = startedAt
  let heard = false
  let ending: 'stop' | 'cancel' | null = null
  let resolve!: (end: TalkEnd) => void
  const done = new Promise<TalkEnd>((r) => (resolve = r))

  const release = () => {
    stopTicks()
    meter?.close()
    stream.getTracks().forEach((track) => track.stop())
  }
  const listen = () => {
    const now = deps.now()
    try {
      if (meter && meter.level() >= SOUND_LEVEL) {
        lastSoundAt = now
        if (!heard) {
          heard = true
          options.onHeard?.()
        }
      }
    } catch {
      // A meter that fails only loses the silence stop; 5 min still holds.
    }
    if (now - startedAt >= MAX_TALK_MS || now - lastSoundAt >= SILENCE_MS) end('stop')
  }
  const stopTicks = deps.every(TICK_MS, listen)

  recorder.onData = (blob) => {
    if (blob.size) chunks.push(blob)
  }
  recorder.onStop = () => {
    release()
    if (ending === 'cancel') return
    const blob = new Blob(chunks, { type })
    if (!heard || !blob.size) return resolve({ kind: 'empty' })
    if (blob.size > MAX_AUDIO_BYTES) return resolve({ kind: 'too-long' })
    toBase64(blob).then(
      (data) => resolve({ kind: 'audio', audio: { mimeType: type, data } }),
      () => resolve({ kind: 'failed' }),
    )
  }

  function end(how: 'stop' | 'cancel') {
    if (ending) return
    ending = how
    if (how === 'cancel') {
      chunks.length = 0
      resolve({ kind: 'cancelled' })
    }
    try {
      recorder.stop()
    } catch {
      release()
      if (how === 'stop') resolve({ kind: 'failed' })
    }
  }

  recorder.start()
  return { stop: () => end('stop'), cancel: () => end('cancel'), done }
}
