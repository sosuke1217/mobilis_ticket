# config/importmap.rb - 簡単版
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

# FullCalendar
pin "fullcalendar", to: "fullcalendar.js", preload: true

# Calendar modules - vendor directory
pin "calendar", to: "calendar/index.js", preload: true
pin "calendar_core", to: "calendar/calendar_core.js", preload: true
pin "modal", to: "calendar/modal.js", preload: true
pin "interval_settings", to: "calendar/interval_settings.js", preload: true
pin "reservation_form", to: "calendar/reservation_form.js", preload: true
pin "utils", to: "calendar/utils.js", preload: true