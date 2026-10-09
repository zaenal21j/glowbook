import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["latitude", "longitude", "status", "button"]

  locate(event) {
    event.preventDefault()

    if (!navigator.geolocation) {
      this.statusTarget.textContent = "Browser ini tidak mendukung akses lokasi."
      return
    }

    this.buttonTarget.disabled = true
    this.statusTarget.textContent = "Meminta izin lokasi dari browser…"

    navigator.geolocation.getCurrentPosition(
      (position) => {
        this.latitudeTarget.value = position.coords.latitude.toFixed(6)
        this.longitudeTarget.value = position.coords.longitude.toFixed(6)
        this.statusTarget.textContent = "Lokasi ditemukan. Mengurutkan bisnis terdekat…"
        this.element.requestSubmit()
      },
      (error) => {
        this.buttonTarget.disabled = false
        this.statusTarget.textContent = error.code === error.PERMISSION_DENIED
          ? "Izin lokasi ditolak. Aktifkan izin lokasi browser untuk mengurutkan berdasarkan jarak."
          : "Lokasi tidak berhasil didapatkan. Periksa izin lokasi lalu coba lagi."
      },
      { enableHighAccuracy: false, maximumAge: 300000, timeout: 10000 }
    )
  }
}
