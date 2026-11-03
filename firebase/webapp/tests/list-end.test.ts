import { afterEach, describe, expect, it, vi } from 'vitest'
import { watchListEnd } from '@/lib/orders/list-end'

// A stand-in for IntersectionObserver that, like the browser, reports an element
// once when observed and then only when its visibility changes.
class FakeObserver {
  static last: FakeObserver
  observed = new Set<Element>()
  visible = true
  constructor(private callback: (entries: { isIntersecting: boolean }[]) => void) {
    FakeObserver.last = this
  }
  observe(element: Element) {
    this.observed.add(element)
    queueMicrotask(() => this.observed.has(element) && this.callback([{ isIntersecting: this.visible }]))
  }
  unobserve(element: Element) {
    this.observed.delete(element)
  }
  disconnect() {
    this.observed.clear()
  }
}

const flush = async () => {
  for (let i = 0; i < 20; i++) await Promise.resolve()
}

describe('watchListEnd (home.list.load-more)', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('keeps loading while the end of a filtered list stays on screen, until there is no more', async () => {
    vi.stubGlobal('IntersectionObserver', FakeObserver)
    let pages = 3
    const loadMore = vi.fn(async () => {
      if (!pages) return false
      pages--
      return true
    })
    const end = watchListEnd(loadMore)
    end.watch(document.createElement('div'))
    await flush()
    // Three pages, then one call that finds nothing more and stops.
    expect(loadMore).toHaveBeenCalledTimes(4)
  })

  it('stops when the end leaves the screen or a page fails', async () => {
    vi.stubGlobal('IntersectionObserver', FakeObserver)
    const loadMore = vi.fn(async () => false)
    const end = watchListEnd(loadMore)
    end.watch(document.createElement('div'))
    await flush()
    expect(loadMore).toHaveBeenCalledTimes(1)

    const scrolled = vi.fn(async () => true)
    const other = watchListEnd(scrolled)
    FakeObserver.last.visible = false
    other.watch(document.createElement('div'))
    await flush()
    expect(scrolled).not.toHaveBeenCalled()
  })

  it('no sentinel (no more pages): nothing is watched', async () => {
    vi.stubGlobal('IntersectionObserver', FakeObserver)
    const loadMore = vi.fn(async () => true)
    const end = watchListEnd(loadMore)
    const sentinel = document.createElement('div')
    end.watch(sentinel)
    end.watch(null)
    await flush()
    expect(loadMore).not.toHaveBeenCalled()
  })
})
