const assert = require("node:assert/strict")
const { test } = require("node:test")
const { readFileSync } = require("node:fs")
const { resolve } = require("node:path")
const vm = require("node:vm")

const origin = "http://localhost:3000"
const source = readFileSync(resolve(__dirname, "../../app/views/pwa/service-worker.js"), "utf8")

function harness() {
  const handlers = new Map()
  const stores = new Map()
  let fetcher = async () => { throw new Error("offline") }
  let waiting = false
  let claimed = false
  const key = (request) => new URL(typeof request === "string" ? request : request.url, origin).href
  const caches = {
    async open(name) {
      if (!stores.has(name)) stores.set(name, new Map())
      const store = stores.get(name)
      return {
        async addAll(urls) { urls.forEach((url) => store.set(key(url), new Response(`cached:${url}`))) },
        async put(request, response) { store.set(key(request), response.clone()) }
      }
    },
    async match(request) {
      for (const store of stores.values()) {
        if (store.has(key(request))) return store.get(key(request)).clone()
      }
    },
    async keys() { return [...stores.keys()] },
    async delete(name) { return stores.delete(name) }
  }
  vm.runInNewContext(source, {
    URL, Response, caches, fetch: (...args) => fetcher(...args),
    self: {
      location: { origin },
      addEventListener: (name, callback) => handlers.set(name, callback),
      skipWaiting: async () => { waiting = true },
      clients: { claim: async () => { claimed = true } }
    }
  })
  return {
    caches, stores,
    setFetch(fn) { fetcher = fn },
    get waiting() { return waiting },
    get claimed() { return claimed },
    async dispatch(name, request) {
      let result
      handlers.get(name)({ request, waitUntil: (promise) => { result = promise }, respondWith: (promise) => { result = promise } })
      return result
    }
  }
}

const request = (path, mode = "cors", method = "GET") => ({ url: new URL(path, origin).href, mode, method })

test("installation caches offline fallback and icons", async () => {
  const worker = harness()
  await worker.dispatch("install")
  assert.equal(await (await worker.caches.match("/offline.html")).text(), "cached:/offline.html")
  assert.ok(await worker.caches.match("/icon.png"))
  assert.ok(await worker.caches.match("/icon.svg"))
  assert.equal(worker.waiting, true)
})

test("activation removes only old GlowBook caches", async () => {
  const worker = harness()
  await worker.caches.open("glowbook-static-v1")
  await worker.caches.open("other-application-cache")
  await worker.dispatch("install")
  await worker.dispatch("activate")
  assert.equal(worker.stores.has("glowbook-static-v1"), false)
  assert.equal(worker.stores.has("other-application-cache"), true)
  assert.equal(worker.claimed, true)
})

test("offline navigation returns the cached fallback", async () => {
  const worker = harness()
  await worker.dispatch("install")
  const response = await worker.dispatch("fetch", request("/akun", "navigate"))
  assert.equal(await response.text(), "cached:/offline.html")
})

test("online account and admin pages are fetched without being cached", async () => {
  const worker = harness()
  worker.setFetch(async () => new Response("private page"))
  for (const path of ["/akun", "/admin", "/booking/GB-PRIVATE"]) {
    const response = await worker.dispatch("fetch", request(path, "navigate"))
    assert.equal(await response.text(), "private page")
    assert.equal(await worker.caches.match(path), undefined)
  }
})

test("downloaded static assets remain available offline", async () => {
  const worker = harness()
  worker.setFetch(async () => {
    const response = new Response("asset contents")
    Object.defineProperty(response, "type", { value: "basic" })
    return response
  })
  const asset = request("/assets/application-test.css")
  const online = await worker.dispatch("fetch", asset)
  assert.equal(await online.text(), "asset contents")
  worker.setFetch(async () => { throw new Error("offline") })
  const offline = await worker.dispatch("fetch", asset)
  assert.equal(await offline.text(), "asset contents")
})

test("messages, foreign origins, and mutations are not intercepted", async () => {
  const worker = harness()
  for (const input of [request("/chat/1/pesan"), request("https://example.com/image.png"), request("/booking/1/cancel", "cors", "PATCH")]) {
    assert.equal(await worker.dispatch("fetch", input), undefined)
  }
  assert.equal(worker.stores.size, 0)
})

test("the offline page uses the saved English language preference", () => {
  const html = readFileSync(resolve(__dirname, "../../public/offline.html"), "utf8")
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1]
  const elements = new Map(["offline-title", "offline-description", "offline-retry"].map((id) => [id, { textContent: "" }]))
  const document = { documentElement: { lang: "id" }, getElementById: (id) => elements.get(id) }
  vm.runInNewContext(script, { document, localStorage: { getItem: () => "en" } })
  assert.equal(document.documentElement.lang, "en")
  assert.equal(elements.get("offline-title").textContent, "You are offline")
  assert.equal(elements.get("offline-retry").textContent, "Try again")
})
