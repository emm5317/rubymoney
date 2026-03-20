import { Controller } from "@hotwired/stimulus"

// Handles chart click events and loads transaction drill-down via Turbo Frame.
// Listens for chart:click custom events dispatched by the chart controller.
export default class extends Controller {
  static values = {
    url: String,
    ids: Array,
    month: Number,
    year: Number
  }

  onChartClick(event) {
    const { index } = event.detail
    const categoryId = this.idsValue[index]
    if (categoryId === undefined || categoryId === "other") return

    const frame = document.getElementById("drilldown-frame")
    if (!frame) return

    const params = new URLSearchParams({
      month: this.monthValue,
      year: this.yearValue
    })
    if (categoryId !== null) params.set("category_id", categoryId)

    frame.src = `${this.urlValue}?${params.toString()}`
    frame.closest("[data-drilldown-container]")?.classList?.remove("hidden")
  }
}
