// When the assistant's presentation shows (order.ai.intro), the app's
// showAiIntroOnce: once per browser (the app: once per phone), only with the
// assistant on, only with the screen settled (Início, nothing open). Saved as
// seen before it shows; an assistant still off saves nothing, so it can show
// once it is turned on.
import { readStorage, writeStorage } from '@/lib/storage'

export const AI_INTRO_KEY = 'praticos.aiIntroSeen.v1'

export async function shouldShowAiIntro(settled: () => boolean, enabled: () => Promise<boolean>): Promise<boolean> {
  if (readStorage(AI_INTRO_KEY) === '1') return false
  let on = false
  try {
    on = await enabled()
  } catch {
    return false
  }
  if (!on || !settled()) return false
  writeStorage(AI_INTRO_KEY, '1')
  return true
}
