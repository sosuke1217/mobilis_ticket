# config/importmap.rb - 簡単版
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

# FullCalendar
pin "fullcalendar", to: "fullcalendar.js", preload: true

# Calendar modules - vendor directory
pin_all_from "vendor/javascript/calendar", under: "calendar"