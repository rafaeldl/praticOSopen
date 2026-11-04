// Whether this browser can record (Falar shows only then). Kept apart from
// talk.ts, which loads only when Falar is tapped.
export function talkSupported(): boolean {
  return typeof window !== 'undefined' && typeof window.MediaRecorder !== 'undefined' && !!navigator.mediaDevices?.getUserMedia
}
