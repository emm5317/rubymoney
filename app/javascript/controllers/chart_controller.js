import { Controller } from "@hotwired/stimulus"

const CHART_JS_SRC = "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"
let chartJsPromise

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

    loadChartJs().then((Chart) => {
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

function loadChartJs() {
  if (window.Chart) return Promise.resolve(window.Chart)
  if (chartJsPromise) return chartJsPromise

  chartJsPromise = new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-chartjs-loader="true"]`)
    if (existing) {
      existing.addEventListener("load", () => resolve(window.Chart), { once: true })
      existing.addEventListener("error", () => reject(new Error("Chart.js failed to load")), { once: true })
      return
    }

    const script = document.createElement("script")
    script.src = CHART_JS_SRC
    script.async = true
    script.dataset.chartjsLoader = "true"
    script.onload = () => {
      if (window.Chart) {
        resolve(window.Chart)
      } else {
        reject(new Error("Chart.js loaded but window.Chart is unavailable"))
      }
    }
    script.onerror = () => reject(new Error("Chart.js failed to load"))
    document.head.appendChild(script)
  })

  return chartJsPromise
}
