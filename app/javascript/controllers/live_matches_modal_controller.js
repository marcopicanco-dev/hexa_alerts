import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
    document.documentElement.classList.add("overflow-hidden")
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  unlock() {
    document.documentElement.classList.remove("overflow-hidden")
  }

  disconnect() {
    this.unlock()
  }
}
