import "@hotwired/turbo-rails"
import "controllers"
import "bootstrap"
import "font-awesome"

document.addEventListener("turbo:load", () => {
  if (window.Chartkick) {
    Chartkick.eachChart(chart => chart.redraw());
  }
});
