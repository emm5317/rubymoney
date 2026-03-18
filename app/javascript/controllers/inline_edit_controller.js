import { Controller } from "@hotwired/stimulus"

// Toggles between display mode and edit mode for inline editing.
// Click the display element to show the form, form auto-submits on change.
export default class extends Controller {
  static targets = ["display", "form"]

  toggle() {
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    const select = this.formTarget.querySelector("select")
    if (select) select.focus()
  }

  submit() {
    this.formTarget.querySelector("form")?.requestSubmit()
  }

  cancel() {
    this.displayTarget.classList.remove("hidden")
    this.formTarget.classList.add("hidden")
  }
}
