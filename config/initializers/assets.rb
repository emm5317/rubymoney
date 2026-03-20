# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("app/javascript")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += [
  "application.js",
  "controllers/application.js",
  "controllers/index.js",
  "controllers/bulk_select_controller.js",
  "controllers/chart_controller.js",
  "controllers/drilldown_controller.js",
  "controllers/inline_edit_controller.js",
  "controllers/nav_toggle_controller.js"
]
