import { Controller } from "@hotwired/stimulus"

// Renders a Chart.js chart from a JSON config passed via data attribute.
// Automatically formats monetary values in tooltips (divides by 100, adds $ prefix).
//
// Usage:
//   <div data-controller="chart" data-chart-config-value='<%= config.to_json %>'
//        data-chart-currency-value="true">
//     <canvas></canvas>
//   </div>
export default class extends Controller {
  static values = {
    config: Object,
    currency: { type: Boolean, default: true }
  }

  connect() {
    if (this.chart) { this.chart.destroy(); this.chart = null }

    import("chart.js").then(({ Chart, registerables }) => {
      Chart.register(...registerables)
      const canvas = this.element.querySelector("canvas")
      if (!canvas) return

      const config = structuredClone(this.configValue)

      // Add currency formatting to tooltips and Y-axis if enabled
      if (this.currencyValue) {
        const formatCents = (value) =>
          "$" + (value / 100).toLocaleString("en-US", {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
          })

        config.options = config.options || {}
        config.options.plugins = config.options.plugins || {}
        config.options.plugins.tooltip = config.options.plugins.tooltip || {}
        config.options.plugins.tooltip.callbacks = {
          ...config.options.plugins.tooltip.callbacks,
          label: (ctx) => {
            const value = ctx.parsed.y !== undefined ? ctx.parsed.y : ctx.parsed
            return `${ctx.label || ctx.dataset.label}: ${formatCents(value)}`
          }
        }

        // Format Y-axis ticks if scales exist (bar/line charts)
        if (config.options.scales?.y?.ticks?.callback === "currency") {
          config.options.scales.y.ticks.callback = (value) => formatCents(value)
        }
      }

      // Emit click events for drill-down
      config.options = config.options || {}
      config.options.onClick = (evt, elements) => {
        if (elements.length > 0) {
          this.element.dispatchEvent(
            new CustomEvent("chart:click", {
              detail: { index: elements[0].index, datasetIndex: elements[0].datasetIndex },
              bubbles: true
            })
          )
        }
      }

      this.chart = new Chart(canvas, config)
    }).catch((err) => {
      console.error("Failed to load Chart.js:", err)
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
