const CACHE_PREFIX = "glowbook-static-"
const CACHE_NAME = `${CACHE_PREFIX}v3`
const FALLBACK_PAGE = "/offline.html"
const PRECACHE_URLS = [FALLBACK_PAGE, "/icon.png", "/icon-192.png", "/icon.svg"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys
        .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
        .map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  const request = event.request
  const url = new URL(request.url)

  if (request.method !== "GET" || url.origin !== self.location.origin) return

  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(FALLBACK_PAGE)))
    return
  }

  const isStaticAsset = url.pathname.startsWith("/assets/") || ["/icon.png", "/icon-192.png", "/icon.svg"].includes(url.pathname)
  if (!isStaticAsset) return

  event.respondWith(
    fetch(request).then((response) => {
      if (response.ok && response.type === "basic") {
        const copy = response.clone()
        return caches.open(CACHE_NAME)
          .then((cache) => cache.put(request, copy))
          .catch(() => undefined)
          .then(() => response)
      }
      return response
    }).catch(async () => {
      const cached = await caches.match(request)
      return cached || Response.error()
    })
  )
})
