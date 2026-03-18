import { Controller } from "@hotwired/stimulus"

// Manages checkbox selection for bulk operations on transactions.
// Wired to a container wrapping both the table and the bulk action bar.
export default class extends Controller {
  static targets = ["checkbox", "selectAll", "bar", "count", "ids"]

  connect() {
    this.updateBar()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateBar()
  }

  toggle() {
    this.updateBar()
  }

  updateBar() {
    const selected = this.selectedIds()
    const count = selected.length

    if (count > 0) {
      this.barTarget.classList.remove("hidden")
      this.countTarget.textContent = `${count} selected`
    } else {
      this.barTarget.classList.add("hidden")
    }

    // Update all hidden ID fields in bulk forms
    this.idsTargets.forEach(input => {
      input.value = selected.join(",")
    })

    // Update select-all checkbox state
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = count > 0 && count === this.checkboxTargets.length
      this.selectAllTarget.indeterminate = count > 0 && count < this.checkboxTargets.length
    }
  }

  selectedIds() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }
}
