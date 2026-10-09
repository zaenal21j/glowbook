import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.close()
  }

  toggle() {
    const opening = this.menuTarget.classList.contains("hidden")
    this.menuTarget.classList.toggle("hidden", !opening)
    this.buttonTarget.setAttribute("aria-expanded", String(opening))
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOutside(event) {
    if (!this.buttonTarget.contains(event.target) && !this.menuTarget.contains(event.target)) this.close()
  }

  closeOnEscape() {
    if (this.menuTarget.classList.contains("hidden")) return
    this.close()
    this.buttonTarget.focus()
  }
}
