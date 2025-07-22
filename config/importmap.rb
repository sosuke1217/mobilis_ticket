# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@popperjs/core", to: "@popperjs--core.js" # @2.11.8
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"

pin "chartkick", to: "chartkick.js"
pin "chartkick/chart.js", to: "Chart.bundle.js"
pin "chart.js" # @4.4.9
pin "@kurkle/color", to: "@kurkle--color.js" # @0.3.4
pin "font-awesome", to: "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/js/all.min.js"
pin "@fullcalendar/core", to: "@fullcalendar--core.js" # @6.1.18
pin "preact" # @10.12.1
pin "preact/compat", to: "preact--compat.js" # @10.12.1
pin "preact/hooks", to: "preact--hooks.js" # @10.12.1
pin "@fullcalendar/daygrid", to: "@fullcalendar--daygrid.js" # @6.1.18
pin "@fullcalendar/timegrid", to: "@fullcalendar--timegrid.js" # @6.1.18
pin "@fullcalendar/interaction", to: "@fullcalendar--interaction.js" # @6.1.18
