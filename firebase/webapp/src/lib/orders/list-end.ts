/**
 * Infinite scroll of the order list (home.list.load-more). The screen filters
 * the loaded rows (Paradas, Orçamentos…), so a page can add no visible row: the
 * sentinel stays on screen, and IntersectionObserver only reports changes, so
 * the list used to stop there, with "Mostrar mais" and no sentence under the
 * title (it only counts with the whole list loaded). After each page that came,
 * the sentinel is watched again: if it is still on screen the observer reports
 * it at once and the next page comes, until there is no more.
 */
export function watchListEnd(loadMore: () => Promise<boolean>, rootMargin = '200px') {
  let target: Element | null = null
  const observer = new IntersectionObserver(
    (entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return
      void loadMore().then((loaded) => {
        if (!loaded || !target) return
        observer.unobserve(target)
        observer.observe(target)
      })
    },
    { rootMargin },
  )
  return {
    watch(element: Element | null) {
      if (target) observer.unobserve(target)
      target = element
      if (element) observer.observe(element)
    },
    disconnect() {
      target = null
      observer.disconnect()
    },
  }
}
