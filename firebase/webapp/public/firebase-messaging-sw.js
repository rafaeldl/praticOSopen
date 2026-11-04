// Browser notifications of the web app (docs/WEB_APP.md "Avisos do navegador").
// Registered by src/lib/push/token.ts at /app/ and handed to Firebase Messaging,
// which subscribes it with FCM. No Firebase code here: the push carries FCM's
// JSON ({ notification, data, fcmOptions }) and this file shows it.
// - A tab of the web app on screen: the page shows it (bell and a notice inside),
//   the system does not (as the Firebase worker does).
// - A click: focuses an open tab and tells it what to open, or opens the link.
// Tested in tests/push.test.ts.
;(function (scope) {
  var BASE = new URL('./', scope.location).pathname

  /** The route of a push: the server's link (same site only), else the order of the data, else the start. */
  function linkOf(payload) {
    var options = payload.fcmOptions || payload.fcm_options || {}
    if (options.link) {
      try {
        var url = new URL(options.link, scope.location.origin)
        if (url.pathname.indexOf(BASE) === 0) return url.pathname + url.search
      } catch (error) {
        // An odd link falls back to the data.
      }
    }
    var data = payload.data || {}
    if (!data.orderId) return BASE
    return BASE + '?order=' + encodeURIComponent(data.orderId) + (data.companyId ? '&company=' + encodeURIComponent(data.companyId) : '')
  }

  function appWindows() {
    return scope.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (windows) {
      return windows.filter(function (client) {
        return new URL(client.url).pathname.indexOf(BASE) === 0
      })
    })
  }

  scope.addEventListener('install', function () {
    scope.skipWaiting()
  })

  scope.addEventListener('activate', function (event) {
    event.waitUntil(scope.clients.claim())
  })

  scope.addEventListener('push', function (event) {
    var payload
    try {
      payload = event.data ? event.data.json() : {}
    } catch (error) {
      return
    }
    var notification = payload.notification || {}
    var data = payload.data || {}
    var title = notification.title || 'PraticOS'
    var body = notification.body || ''
    event.waitUntil(
      appWindows().then(function (windows) {
        var visible = windows.filter(function (client) {
          return client.visibilityState === 'visible'
        })
        if (visible.length) {
          visible.forEach(function (client) {
            client.postMessage({ type: 'praticos:notice', title: title, body: body, data: data })
          })
          return
        }
        return scope.registration.showNotification(title, {
          body: body,
          icon: notification.icon || '/logo.png',
          // One notification per order: a new one replaces the previous.
          tag: data.orderId ? 'order-' + data.orderId : undefined,
          data: { link: linkOf(payload) },
        })
      }),
    )
  })

  scope.addEventListener('notificationclick', function (event) {
    event.notification.close()
    var link = (event.notification.data && event.notification.data.link) || BASE
    event.waitUntil(
      appWindows().then(function (windows) {
        var open = windows[0]
        if (open) {
          return Promise.resolve(open.focus && open.focus()).then(function () {
            open.postMessage({ type: 'praticos:notice-open', link: link })
          })
        }
        return scope.clients.openWindow(link)
      }),
    )
  })
})(self)
