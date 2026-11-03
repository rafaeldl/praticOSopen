// Whatever opens over a screen enters the browser history, so Voltar closes it
// instead of leaving the app (REVISAO-UX P0 4).
//  - useRoutePanel: the side panel. Its id is in the URL, so the link can be shared.
//  - Layer.vue: drawers, sheets and dialogs, via LAYER_PARAM. Not shareable: a
//    param without its open layer is removed (see stripStaleLayers).
import { computed, onMounted } from 'vue'
import { useRoute, useRouter, type LocationQuery, type RouteLocationNormalized, type Router } from 'vue-router'

export const LAYER_PARAM = 'layer'

/** Keys of the layers on screen. */
export const openLayers = new Set<string>()

export function queryValues(query: LocationQuery, name: string): string[] {
  const value = query[name]
  if (value === undefined || value === null) return []
  return (Array.isArray(value) ? value : [value]).filter((item): item is string => !!item)
}

export function withoutParam(query: LocationQuery, name: string): LocationQuery {
  const copy = { ...query }
  delete copy[name]
  return copy
}

/** Did the app itself reach this entry, or did the visit start on it? */
export function hasAppHistory(router: Router): boolean {
  return !!router.options.history.state.back
}

export function useRoutePanel(name = 'panel') {
  const route = useRoute()
  const router = useRouter()
  const value = computed(() => queryValues(route.query, name)[0] ?? null)

  function open(id: string) {
    const query = { ...route.query, [name]: id }
    return value.value ? router.replace({ query }) : router.push({ query })
  }

  function close() {
    if (hasAppHistory(router)) router.back()
    else void router.replace({ query: withoutParam(route.query, name) })
  }

  // A shared link lands directly on the panel. A list entry is placed behind it,
  // so the first Voltar closes the panel and does not leave the app.
  onMounted(async () => {
    if (value.value && !hasAppHistory(router)) {
      const id = value.value
      await router.replace({ query: withoutParam(route.query, name) })
      await router.push({ query: { ...route.query, [name]: id } })
    }
  })

  return { value, open, close }
}

/** A reload or Voltar into a closed layer: the param means nothing, drop it. */
export function stripStaleLayers(to: RouteLocationNormalized) {
  const layers = queryValues(to.query, LAYER_PARAM)
  const alive = layers.filter((key) => openLayers.has(key))
  if (alive.length === layers.length) return true
  const query = withoutParam(to.query, LAYER_PARAM)
  return { path: to.path, query: alive.length ? { ...query, [LAYER_PARAM]: alive } : query, hash: to.hash, replace: true }
}
