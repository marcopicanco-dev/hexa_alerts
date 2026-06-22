import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]
  static values = { seconds: Number, running: Boolean, updatedAt: String }

  connect() {
    this.render()
    if (this.runningValue) this.timer = window.setInterval(() => this.render(), 1000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  render() {
    const elapsed = this.runningValue && this.updatedAtValue
      ? Math.max(0, Math.floor((Date.now() - Date.parse(this.updatedAtValue)) / 1000))
      : 0
    const total = this.secondsValue + elapsed
    const minutes = Math.floor(total / 60).toString().padStart(2, "0")
    const seconds = (total % 60).toString().padStart(2, "0")
    this.displayTarget.textContent = `${minutes}:${seconds}`
  }
}
