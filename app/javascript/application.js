// GlowBook JS entrypoint: Turbo + Stimulus
import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" }).catch((error) => {
      console.error("GlowBook service worker registration failed:", error)
    })
  })
}
