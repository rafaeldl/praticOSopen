// Named points of the startup, read by e2e/perf/list-visible.spec.ts.
export function mark(name: string): void {
  try {
    if (performance.getEntriesByName(name).length === 0) performance.mark(name)
  } catch {
    // Old browsers without User Timing: nothing to measure.
  }
}
