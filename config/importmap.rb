# Pin local modules.
pin "application"

# Hotwire
pin "turbo", to: "turbo.min.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

# Local controllers
pin_all_from "app/javascript/controllers", under: "controllers"
