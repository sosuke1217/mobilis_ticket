import "@hotwired/turbo-rails"
import "controllers"
import "bootstrap"
import "font-awesome"
import "./controllers/reservation_form_controller"

document.addEventListener("turbo:load", () => {
  if (window.Chartkick) {
    Chartkick.eachChart(chart => chart.redraw());
  }
});

document.addEventListener("turbo:load", function () {
  const calendarEl = document.getElementById("calendar");
  if (!calendarEl) return;

  requestAnimationFrame(() => {
    setTimeout(() => {
      calendarEl.innerHTML = "";

      const calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: "timeGridWeek",
        slotMinTime: "10:00:00",
        slotMaxTime: "20:00:00",
        locale: "ja",
        headerToolbar: {
          left: "prev,next today",
          center: "title",
          right: "timeGridDay,timeGridWeek"
        },
        events: "/admin/reservations.json"
      });

      calendar.render();
    }, 30);
  });
});
