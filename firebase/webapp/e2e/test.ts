// Every spec imports `test` from here instead of '@playwright/test'.
//
// Stops the page's live Firestore listeners before the page goes away: at the
// end of the test and before a goto or reload. A listener whose page just
// vanished stays on the emulator, which keeps queuing every matching write for
// it (the board's query gets ~100 messages per write in company A). Over the
// whole suite that filled the emulator: millions of warnings, writes taking
// 30 s and every test after ~600 failing. Closing the stream (terminate) or
// stopping on pagehide is not enough: the targets must be removed while the
// page is still up, so the "remove target" messages go out.
import { test as base, type Page } from '@playwright/test'

export * from '@playwright/test'

async function stopListeners(pages: Page[]): Promise<void> {
  const open = pages.filter((p) => !p.isClosed())
  const stopped = await Promise.all(
    open.map((p) =>
      p
        .evaluate(() => {
          const stop = (window as unknown as { __e2eStopListeners?: () => void }).__e2eStopListeners
          stop?.()
          return !!stop
        })
        .catch(() => false),
    ),
  )
  if (stopped.some(Boolean)) await new Promise((resolve) => setTimeout(resolve, 300))
}

export const test = base.extend<{ stopListeners: void }>({
  page: async ({ page }, use) => {
    const goto = page.goto.bind(page)
    const reload = page.reload.bind(page)
    page.goto = async (...args) => {
      await stopListeners([page])
      return goto(...args)
    }
    page.reload = async (...args) => {
      await stopListeners([page])
      return reload(...args)
    }
    await use(page)
  },
  stopListeners: [
    // Depends on `page` so it runs before the page closes; also a second person's context.
    async ({ page, browser }, use) => {
      void page
      await use()
      await stopListeners(browser.contexts().flatMap((context) => context.pages()))
    },
    { auto: true },
  ],
})
