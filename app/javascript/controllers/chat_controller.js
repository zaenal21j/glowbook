import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "emptyState"]
  static values = { url: String, afterId: Number }

  connect() {
    this.scrollToLatest()
    this.timer = window.setInterval(() => this.refresh(), 4000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  async refresh() {
    if (document.hidden) return

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("after_id", this.afterIdValue)
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      if (!response.ok) return

      const messages = await response.json()
      messages.forEach((message) => this.appendMessage(message))
    } catch (_error) {
      // The next poll retries when the connection returns.
    }
  }

  appendMessage(message) {
    if (message.id <= this.afterIdValue) return

    const row = document.createElement("div")
    row.id = `chat-message-${message.id}`
    row.className = `flex ${message.mine ? "justify-end" : "justify-start"}`

    const article = document.createElement("article")
    article.className = message.mine
      ? "max-w-[85%] rounded-2xl bg-primary-600 p-3 text-sm text-white"
      : "max-w-[85%] rounded-2xl bg-gray-100 p-3 text-sm text-ink-900"

    const sender = document.createElement("p")
    sender.className = `mb-1 text-xs font-semibold ${message.mine ? "text-white/80" : "text-ink-500"}`
    sender.textContent = message.mine ? "Anda" : message.sender

    const body = document.createElement("p")
    body.className = "whitespace-pre-wrap break-words"
    body.textContent = message.body

    const time = document.createElement("time")
    time.className = `mt-1 block text-right text-[10px] ${message.mine ? "text-white/70" : "text-ink-400"}`
    time.textContent = message.time

    article.append(sender, body, time)
    row.append(article)
    if (this.hasEmptyStateTarget) this.emptyStateTarget.remove()
    this.messagesTarget.append(row)
    this.afterIdValue = message.id
    this.scrollToLatest()
  }

  scrollToLatest() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
