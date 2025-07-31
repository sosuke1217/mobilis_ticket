# config/importmap.rb
# 最小限の設定のみ

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "fullcalendar", to: "https://cdn.jsdelivr.net/npm/fullcalendar@6.1.10/index.global.min.js"
pin "fullcalendar-timegrid", to: "https://cdn.jsdelivr.net/npm/@fullcalendar/timegrid@6.1.10/index.global.min.js"
pin "calendar_core", to: "calendar_core.js"
pin "utils", to: "utils.js"
pin "modal_controller", to: "modal_controller.js"
pin "interval_settings", to: "interval_settings.js"
pin "reservation_form", to: "reservation_form.js"
