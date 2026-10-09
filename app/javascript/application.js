// GlowBook JS entrypoint: Turbo + Stimulus
import "@hotwired/turbo-rails"
import "controllers"

try {
  localStorage.setItem("glowbook_locale", document.documentElement.lang)
} catch (_) {
  // Storage may be unavailable in private browser sessions.
}

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch((error) => {
      console.error("GlowBook service worker registration failed:", error)
    })
  })
}
